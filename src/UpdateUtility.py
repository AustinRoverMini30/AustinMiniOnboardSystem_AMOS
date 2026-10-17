import io
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

import requests


REPOSITORY_OWNER = "AustinRoverMini30"
REPOSITORY_NAME = "AustinMiniOnboardSystem_AMOS"
PROJECT_ROOT = Path(__file__).resolve().parent.parent


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
            members = [member for member in zip_file.infolist() if not member.is_dir()]
            components = [member.filename.split("/", 1)[0] for member in members]
            root_folder = components[0] if components and all(
                component == components[0] for component in components
            ) else None

            for index, member in enumerate(members, start=1):
                member_name = member.filename
                relative_path = member_name
                if root_folder and member_name.startswith(root_folder + "/"):
                    relative_path = member_name[len(root_folder) + 1:]
                if not relative_path:
                    continue

                destination = _safe_destination(PROJECT_ROOT, relative_path)
                destination.parent.mkdir(parents=True, exist_ok=True)
                with zip_file.open(member) as source, destination.open("wb") as target:
                    shutil.copyfileobj(source, target)

                permissions = member.external_attr >> 16
                if permissions:
                    destination.chmod(permissions)
                if status_callback:
                    status_callback(f"Extraction... {index}/{len(members)}")

        if status_callback:
            status_callback("Mise à jour terminée.")
        print(f"Mise à jour vers la version {tag} terminée !")
        return True
    except (OSError, requests.RequestException, zipfile.BadZipFile, ValueError) as error:
        message = f"Erreur: {error}"
        print(f"Erreur lors de la mise à jour: {error}")
        if status_callback:
            status_callback(message)
        return False


def restart_application():
    subprocess.Popen(["sudo", "reboot"])
