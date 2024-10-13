import re
import sys
import json
import os


def argument_parser(arguments):
    path = 0
    reseau = ""
    help = 0
    for i in range(0, len(arguments)):
        if arguments[i] == "-r":
            reseau = arguments[i+1]
        elif arguments[i] == "-p":
            path = arguments[i+1]
        elif arguments[i] == "-h":
            help = 1
    return reseau, path, help

def create_regex(regex_file, reseau):
    with open(regex_file, 'r') as regex_f:
        regex = json.load(regex_f)
    regex["domain"] = reseau
    
    liste_serveur = f"{sys.path[0]}\\liste_serveurs\\{reseau}.txt"
    
    with open(liste_serveur, 'r') as f:
        extra_servers = f.read().splitlines()
        for i in range(0, len(extra_servers)):
            regex[f"server{i}"] = extra_servers[i]
            
    return regex

def modify_file(regex, file):
    with open(file, 'r') as fichier:
        data = fichier.read()
        for entry in regex.keys():
            data = re.sub(regex[entry], entry, data)
            
    with open(file, 'w') as fichier:
        fichier.write(data)

def list_folders(path):
    try:
        return [f.path for f in os.scandir(path) if f.is_dir()]
    except:
        return path
    
def list_files(path):
    return [f.path for f in os.scandir(path) if f.is_file()]
        
def get_all_files(path):
    if os.path.isfile(path):
        return path
    else:
        folder_files = list_files(path)
        liste_sub_folders = list_folders(path)
        
        for subfolder in liste_sub_folders:
            folder_files += list_files(subfolder)
            liste_sub_folders += get_all_files(subfolder)[0]
        return liste_sub_folders, folder_files

def modify_path(regex, path):
    all_files = get_all_files(path)
    if type(all_files) == str:
        print(all_files)
        modify_file(regex=regex, file=all_files)
    else:
        for file in all_files[1]:
            modify_file(regex=regex, file=file)

def main(reseau, path):
    regex = create_regex(f'{sys.path[0]}\\liste_serveurs\\regex.json', reseau)
    modify_path(regex=regex, path=path)
    
    
if __name__ == "__main__":
    try:
        arguments = argument_parser(sys.argv)
        help = arguments[2]
        if help == 1:
            print(''' Guide d'utilisation du script de blanchissement:
                -r : reseau parmis la liste: [liste des réseaux]
                -p : path vers le dossier ou fichier à blanchir
                ''')
        else:
            reseau = arguments[0]
            path = arguments[1]
            
            main(path=path, reseau=reseau)
    
    except IndexError:
        print("Erreur d'utilisation du script. Lancer 'blanchissement.py -h' pour voir le guide")
