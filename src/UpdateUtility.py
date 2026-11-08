import io
import os
import re
import shutil
import subprocess
import zipfile
from pathlib import Path, PurePosixPath

import psutil
import requests


REPOSITORY_OWNER = "AustinRoverMini30"
REPOSITORY_NAME = "AustinMiniOnboardSystem_AMOS"
PROJECT_ROOT = Path(__file__).resolve().parent.parent
USB_MOUNT_BASES = (Path("/media"), Path("/run/media"), Path("/mnt"))
UPDATE_ARCHIVE_PATTERN = re.compile(
    r"^AustinMiniOnboardSystem_AMOS_(v?\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.]+)?)\.zip$"
)
VERSION_PATTERN = re.compile(r"^v?\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.]+)?$")


def _version_number(version):
    return str(version).strip().lstrip("v")


def get_current_version():
    return (PROJECT_ROOT / "VERSION").read_text(encoding="utf-8").strip()


def get_latest_version_from_github(repo_owner=REPOSITORY_OWNER, repo_name=REPOSITORY_NAME):
    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/releases/latest"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json().get("tag_name")


def check_for_updates():
    current_version = _version_number(get_current_version())
    latest_version = get_latest_version_from_github()

    if latest_version and _version_number(latest_version) != current_version:
        print(f"Une nouvelle version est disponible : {latest_version} (vous avez {current_version})")
        return latest_version

    print("Votre version est à jour.")
    return None


def check_for_updates_and_prompt():
    current = get_current_version()
    latest = check_for_updates()
    if latest:
        return f"{current} -> {latest} : Mise à jour disponible !"
    return f"{current} : Aucune mise à jour disponible."


def _safe_destination(project_root, relative_path):
    destination = (project_root / relative_path).resolve()
    if os.path.commonpath((str(project_root), str(destination))) != str(project_root):
        raise ValueError(f"Chemin ignoré (tentative d'évasion) : {relative_path}")
    return destination


def _mounted_usb_paths():
    paths = set()
    for partition in psutil.disk_partitions(all=True):
        mountpoint = Path(partition.mountpoint)
        if any(mountpoint == base or base in mountpoint.parents for base in USB_MOUNT_BASES):
            paths.add(mountpoint)
    return sorted(paths)


def _archive_project_files(zip_file):
    files = [member for member in zip_file.infolist() if not member.is_dir()]
    version_members = [
        member for member in files
        if PurePosixPath(member.filename).name == "VERSION"
    ]
    if len(version_members) != 1:
        raise ValueError("L'archive doit contenir un unique fichier VERSION.")

    version_path = PurePosixPath(version_members[0].filename)
    if version_path.is_absolute() or ".." in version_path.parts:
        raise ValueError("Chemin VERSION invalide dans l'archive.")
    root_parts = version_path.parts[:-1]

    project_files = []
    for member in files:
        member_path = PurePosixPath(member.filename)
        if member_path.is_absolute() or ".." in member_path.parts:
            raise ValueError(f"Chemin invalide dans l'archive : {member.filename}")
        if root_parts:
            if member_path.parts[:len(root_parts)] != root_parts:
                raise ValueError("Les fichiers de l'archive ne partagent pas le dossier du projet.")
            relative_parts = member_path.parts[len(root_parts):]
        else:
            relative_parts = member_path.parts
        if relative_parts:
            project_files.append((member, PurePosixPath(*relative_parts)))

    project_files.sort(key=lambda entry: entry[1] == PurePosixPath("VERSION"))
    return project_files, version_members[0]


def get_update_archive_version(archive_path):
    archive_path = Path(archive_path)
    match = UPDATE_ARCHIVE_PATTERN.fullmatch(archive_path.name)
    if not match:
        raise ValueError(
            "Le nom de l'archive doit suivre le format "
            "AustinMiniOnboardSystem_AMOS_v<version>.zip."
        )

    with zipfile.ZipFile(archive_path) as zip_file:
        _, version_member = _archive_project_files(zip_file)
        version = zip_file.read(version_member).decode("utf-8").strip()

    if (
        not VERSION_PATTERN.fullmatch(version)
        or _version_number(version) != _version_number(match.group(1))
    ):
        raise ValueError("La version de VERSION ne correspond pas au nom de l'archive.")
    return version


def find_usb_update_archive(mount_points=None):
    """Return the first valid AMOS version archive found at a mounted USB root."""
    for mountpoint in mount_points if mount_points is not None else _mounted_usb_paths():
        for archive_path in sorted(
            Path(mountpoint).glob("AustinMiniOnboardSystem_AMOS_*.zip")
        ):
            version = get_update_archive_version(archive_path)
            return archive_path, version
    return None


def install_update_archive(archive_path, expected_version, status_callback=None):
    """Install a validated local AMOS archive into the project directory."""
    archive_path = Path(archive_path)
    try:
        if status_callback:
            status_callback("Vérification de l'archive USB...")

        archive_name_match = UPDATE_ARCHIVE_PATTERN.fullmatch(archive_path.name)
        if not archive_name_match:
            raise ValueError(
                "Le nom de l'archive doit suivre le format "
                "AustinMiniOnboardSystem_AMOS_v<version>.zip."
            )

        with zipfile.ZipFile(archive_path) as zip_file:
            project_files, version_member = _archive_project_files(zip_file)
            version = zip_file.read(version_member).decode("utf-8").strip()
            if (
                not VERSION_PATTERN.fullmatch(version)
                or _version_number(version) != _version_number(expected_version)
                or _version_number(version) != _version_number(archive_name_match.group(1))
            ):
                raise ValueError("La version de l'archive a changé ou ne correspond pas.")

            if status_callback:
                status_callback("Extraction de l'archive USB...")

            for index, (member, relative_path) in enumerate(project_files, start=1):
                destination = _safe_destination(PROJECT_ROOT, str(relative_path))
                destination.parent.mkdir(parents=True, exist_ok=True)
                with zip_file.open(member) as source, destination.open("wb") as target:
                    shutil.copyfileobj(source, target)

                permissions = member.external_attr >> 16
                if permissions:
                    destination.chmod(permissions)
                if status_callback:
                    status_callback(f"Extraction... {index}/{len(project_files)}")

        if status_callback:
            status_callback("Mise à jour USB terminée.")
        return True
    except (OSError, UnicodeDecodeError, zipfile.BadZipFile, ValueError) as error:
        if status_callback:
            status_callback(f"Erreur : {error}")
        return False


def download_latest_release(version, progress_callback=None, status_callback=None):
    """Télécharge et installe une release GitHub dans le répertoire du projet."""
    if status_callback:
        status_callback("Connexion au serveur...")

    tag = f"v{_version_number(version)}"
    release_url = (
        f"https://github.com/{REPOSITORY_OWNER}/{REPOSITORY_NAME}"
        f"/archive/refs/tags/{tag}.zip"
    )

    try:
        with requests.get(release_url, stream=True, timeout=30) as response:
            response.raise_for_status()
            total_size = int(response.headers.get("content-length", 0))
            downloaded = 0
            content = io.BytesIO()

            if status_callback:
                status_callback("Téléchargement en cours...")

            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    content.write(chunk)
                    downloaded += len(chunk)
                    if progress_callback and total_size:
                        progress_callback(downloaded, total_size)

        if status_callback:
            status_callback("Extraction des fichiers...")

        with zipfile.ZipFile(io.BytesIO(content.getvalue())) as zip_file:
            project_files, _ = _archive_project_files(zip_file)
            for index, (member, relative_path) in enumerate(project_files, start=1):
                destination = _safe_destination(PROJECT_ROOT, str(relative_path))
                destination.parent.mkdir(parents=True, exist_ok=True)
                with zip_file.open(member) as source, destination.open("wb") as target:
                    shutil.copyfileobj(source, target)

                permissions = member.external_attr >> 16
                if permissions:
                    destination.chmod(permissions)
                if status_callback:
                    status_callback(f"Extraction... {index}/{len(project_files)}")

        if status_callback:
            status_callback("Mise à jour terminée.")
        print(f"Mise à jour vers la version {tag} terminée !")
        return True
    except (
        OSError,
        UnicodeDecodeError,
        requests.RequestException,
        zipfile.BadZipFile,
        ValueError,
    ) as error:
        message = f"Erreur: {error}"
        print(f"Erreur lors de la mise à jour: {error}")
        if status_callback:
            status_callback(message)
        return False


def restart_application():
    subprocess.Popen(["sudo", "reboot"])
