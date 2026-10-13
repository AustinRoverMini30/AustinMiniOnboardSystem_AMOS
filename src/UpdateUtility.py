import io
import os
import shutil
import subprocess
import sys
import zipfile

import pygame
import requests


def get_current_version():
    with open("../VERSION", "r") as f:
        return f.read()

def get_latest_version_from_github(repo_owner, repo_name):
    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/releases/latest"
    response = requests.get(url)
    if response.status_code == 200:
        return response.json()["tag_name"]
    return None

def check_for_updates():
    current_version = get_current_version()
    latest_version = get_latest_version_from_github("AustinRoverMini30", "AustinMiniOnboardSystem_AMOS")

    if latest_version and latest_version != current_version:
        print(f"Une nouvelle version est disponible : {latest_version} (vous avez {current_version})")
        return latest_version
    else:
        print("Votre version est à jour.")
        return None

def check_for_updates_and_prompt():

    if check_for_updates() is not None:
        return get_current_version() + "-> " + check_for_updates() + " : Mise à jour disponible !"
    else:
        return get_current_version() + " : Aucune mise à jour disponible."

def download_latest_release(version, progress_callback=None, status_callback=None):
    """
    Télécharge et installe la dernière version.

    Args:
        version: Version à télécharger
        progress_callback: Fonction appelée avec (bytes_downloaded, total_bytes)
        status_callback: Fonction appelée avec (status_message)
    """
    if status_callback:
        status_callback("Connexion au serveur...")

    print(version)
    # URL de la release (remplace par l'URL de ton ZIP)
    release_url = f"https://github.com/AustinRoverMini30/AustinMiniOnboardSystem_AMOS/archive/refs/tags/v{version}.zip"

    try:
        response = requests.get(release_url, stream=True)

        if response.status_code != 200:
            if status_callback:
                status_callback(f"Erreur: Code {response.status_code}")
            print("Échec du téléchargement de la mise à jour.")
            return False

        # Récupérer la taille totale
        total_size = int(response.headers.get('content-length', 0))

        if status_callback:
            status_callback("Téléchargement en cours...")

        # Télécharger dans un buffer avec progression
        downloaded = 0
        chunks = []

        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                chunks.append(chunk)
                downloaded += len(chunk)
                if progress_callback and total_size > 0:
                    progress_callback(downloaded, total_size)

        # Assembler les chunks
        content = b''.join(chunks)

        if status_callback:
            status_callback("Extraction des fichiers...")

        # Extraire le ZIP directement à la racine du projet
        with zipfile.ZipFile(io.BytesIO(content)) as zip_file:
            # Détecter s'il y a un dossier racine unique dans l'archive (ex: AustinMiniOnboardSystem_AMOS-<tag>/...)
            all_names = [name for name in zip_file.namelist() if name and not name.endswith('/')]
            first_components = [name.split('/', 1)[0] for name in zip_file.namelist() if name]
            root_folder = None
            if first_components:
                first = first_components[0]
                if all(comp == first for comp in first_components):
                    root_folder = first

            project_root = os.path.abspath('..')

            total_files = len([m for m in zip_file.infolist() if not m.filename.endswith('/')])
            extracted_files = 0

            for member in zip_file.infolist():
                member_name = member.filename
                # Ignorer les répertoires explicites
                if member_name.endswith('/'):
                    continue

                # Enlever le dossier racine unique si présent
                if root_folder and member_name.startswith(root_folder + '/'):
                    rel_path = member_name[len(root_folder) + 1:]
                else:
                    rel_path = member_name

                if not rel_path:
                    # cas où on tombe sur l'entrée du dossier racine lui-même
                    continue

                # Normaliser et empêcher l'écriture hors du répertoire du projet
                dest_path = os.path.normpath(os.path.join(project_root, rel_path))
                if not dest_path.startswith(project_root):
                    print(f"Chemin ignoré (tentative d'évasion) : {member_name}")
                    continue

                os.makedirs(os.path.dirname(dest_path), exist_ok=True)

                # Extraire le fichier en écrasant si nécessaire
                with zip_file.open(member) as src, open(dest_path, 'wb') as dst:
                    shutil.copyfileobj(src, dst)

                # Restaurer les permissions exécutables si nécessaire
                if member.external_attr >> 16:
                    try:
                        os.chmod(dest_path, member.external_attr >> 16)
                    except Exception:
                        pass

                extracted_files += 1
                if status_callback:
                    status_callback(f"Extraction... {extracted_files}/{total_files}")

        if status_callback:
            status_callback("Finalisation...")

        print(f"Mise à jour vers la version {version} terminée !")

        # Après la mise à jour, tenter de lancer launcher.sh à la racine du projet
        try:
            project_root = os.path.abspath('..')
            launcher_path = os.path.join(project_root, 'launcher.sh')
            if os.path.exists(launcher_path):
                try:
                    os.chmod(launcher_path, 0o755)
                except Exception:
                    pass

                print('Lancement de launcher.sh...')
                if status_callback:
                    status_callback("Redémarrage...")

                # Fermer proprement pygame si en cours
                try:
                    pygame.quit()
                except Exception:
                    pass

                # Lancer le script et quitter ce processus
                try:
                    # Utiliser Popen pour détacher le nouveau processus
                    subprocess.Popen([launcher_path], cwd=project_root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                except Exception as e:
                    print(f"Erreur en lançant launcher.sh : {e}")

                # Quitter l'application actuelle
                sys.exit(0)
            else:
                print('launcher.sh introuvable à la racine du projet ; mise à jour terminée sans relance.')
                if status_callback:
                    status_callback("Mise à jour terminée!")
        except Exception as e:
            print(f"Erreur lors du lancement post-mise-à-jour : {e}")
            if status_callback:
                status_callback(f"Erreur: {e}")
            return False

        return True

    except Exception as e:
        print(f"Erreur lors de la mise à jour: {e}")
        if status_callback:
            status_callback(f"Erreur: {e}")
        return False
