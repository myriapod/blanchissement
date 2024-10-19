#############################################################
## Script de blanchissement des logs/fichiers              ##
## Fait par : Solene Poydenot                              ##
## Date création : 13/10/2024                              ##
## Date dernière modification :                            ##
#############################################################


# Définition des fonctions
function get_reseau {return Read-Host -Prompt "Entrez le nom du reseau concerne parmi $liste_reseau"}
function get_path {return Read-Host -Prompt "Entrez le chemin vers le dossier/fichier a blanchir"}

function test_path($path) {if (-Not (Test-Path $path)) {return $false}}
 
# Affichage de l'aide avec -help
if ($args[0] -eq "-help") {
    Write-Host "Script de blanchissement des logs" -ForegroundColor Green
    Write-Host "
UTILISATION -
    -help : affiche ce message d'aide
    Lancez le script et il vous sera demande:
    - le reseau sur lequel vous voulez blanchir
    - le chemin vers le fichier ou dossier que vous voulez blanchir

CONFIGURATION -"
    Write-Host "
    - Rajout d'un reseau a prendre en compte :" -ForegroundColor Green
    Write-Host "
        Ajouter un fichier texte (sans extension) dans liste-reseau avec le nom du reseau/l'alias que vous lui donnez"
    Write-Host "
    - Blanchissements specifiques aux reseaux :" -ForegroundColor Green
    Write-Host "
        Vous pouvez modifier les fichiers textes dans le dossier liste-reseau en rajoutant sur chaque ligne des mots/noms specifiques a remplacer par 'user_server'"
    Write-Host "
    - regex-ps.json :" -ForegroundColor Green
    Write-Host "
        Vous pouvez rajouter des lignes dans le fichier regex-ps.json pour preciser des noms specifiques a changer / des regles particulieres.
        Il y a un ordre de priorite croissant (les regles en haut du fichier sont lues et remplacees en premieres)

bon blanchissement :)
    "
    Break
}

# Début du script
Write-Host "--------------- Script de blanchissement des logs --------------" -ForegroundColor Green
Write-Host "Lancez le script avec -help pour afficher le guide d'utilisation" -ForegroundColor Green
Write-Host "----------------------------------------------------------------" -ForegroundColor Green

# Récupération de la liste spécifique au réseau (fichiers présents dans \liste-reseau)
$liste_reseau = (Get-ChildItem liste-reseau).Name
$reseau = get_reseau

if (($liste_reseau -contains $reseau) -eq $false) {
    Write-Host "Le reseau n'est pas dans la liste des reseaux disponibles ($liste_reseau)" -ForegroundColor Red
    $reseau = get_reseau
}

# Définition du fichier output
$date = (Get-Date -format "yyyyMMdd")
$output_path = ([string](Get-Location)+"\sortie_blanchissement\"+$date+"_"+$reseau)
if (test_path($output_path) == $false) {mkdir $output_path}

# Récupération de la liste des regex indépendemment du réseau
$regex = (Get-Content (Get-ChildItem -Path (Get-Location) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "regex-ps" })) | Out-String | ConvertFrom-Json
$liste_regex = ((Get-Content (Get-ChildItem -Path (Get-Location) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "regex-ps" })) | Out-String | ConvertFrom-Json | Get-Member | Where-Object { $_.MemberType -match "NoteProperty"}).Name

# Récupération de la liste des serveurs propre au réseau choisi et création d'une regex particulière
$server_regex = "("+[string]::Join(")|(",((Get-ChildItem -Path (Get-Location) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "$reseau" }) | Get-Content))+")"

# Ajout dans la liste des regex
$regex | Add-Member -Name 'user_servers' -Type NoteProperty -Value $server_regex
$liste_regex += "user_servers"

# Récupération du chemin vers le dossier à blanchir
$path = get_path
if (test_path($path) == $false) {
    Write-Host "Le chemin $path n'existe pas, veuillez rentrer un chemin existant" -ForegroundColor Red
    $path = get_path
}
$full_output_path = ($output_path+"\"+$path.Split("\")[-1])

# Copie des fichiers à blanchir
Write-Output "Copie des fichiers a blanchir vers $output_path"
Try {
    Copy-Item -Recurse $path -Destination $full_output_path -errorAction stop
    Write-Host "Fichiers copies." -ForegroundColor Green
} Catch {
    Write-Host "Il y a deja ces dossiers dans $full_output_path" -ForegroundColor Red
    $choice = Read-Host -Prompt "Voulez-vous les ecraser ? (o/N)"
   if ( $choice -eq "o") {
        Remove-Item -r $full_output_path
        Copy-Item -Recurse $path -Destination $full_output_path -Force
        Write-Host "Fichiers ecrases et copies." -ForegroundColor Green
    } else {
        Write-Host "Sortie du programme de blanchissement." -ForegroundColor Red
        Break
    }
}


# Blanchissement des fichiers
Write-Output "Blanchissement des fichiers de $path dans $full_output_path :" -ForegroundColor Green

# Lister les fichiers et dossiers de manière récursive
Get-ChildItem -r  $full_output_path | ForEach-Object {
    # Modifier uniquement les fichiers et pas les dossiers
    if ($_.PsIsContainer -eq $false) {
        Write-Output "En train de blanchir : " ([string](Get-Item $_.FullName | Resolve-Path -Relative))
        
        # Pour chaque entrée de la liste des regex génériques
        for ($i = 0; $i -lt $liste_regex.Length; $i+=1)
        {
            $key = $liste_regex[$i]
            $occurances = (((Get-Content $_.FullName) -match $regex.($key)) | Measure-Object -Line).Lines
            Write-Output " => $key a ete trouve $occurances fois"

            # Remplacer toutes les occrurances de la regex trouvées vers le fichier output
            (Get-Content $_.FullName) -replace $regex.($key), ($key) | Set-Content $_.FullName
        }
    }
}

# Fin du script
Write-Host "--- Sortie du script de blanchissement des logs ---" -ForegroundColor Green