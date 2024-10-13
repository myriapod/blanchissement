#############################################################
## Script de blanchissement des logs/fichiers              ##
## Fait par : Solene Poydenot                              ##
## Date création : 13/10/2024                              ##
## Date dernière modification :                            ##
#############################################################

# Début du script
Write-Output "--- Script de blanchissement des logs ---"

# Récupération de la liste spécifique au réseau
$liste_reseau = "sfr","redhat"
function get_reseau {
    return Read-Host -Prompt "Entrez le nom du réseau concerné parmi $liste_reseau"
}
$reseau = get_reseau
if (($liste_reseau -contains $reseau) -eq $false) {
    Write-Error -Message "Le reseau n'est pas dans la liste des réseaux disponibles ($liste_reseau)"
    $reseau = get_reseau
}

# Récupération de la liste des serveurs propre au réseau choisi
$server_list_path = (Get-ChildItem -Path (Get-Location) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "$reseau" })
$server_list = (Get-Content $server_list_path)

# Récupération de la liste des regex indépendemment du réseau
$regex = (Get-Content (Get-ChildItem -Path (Get-Location) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "regex-ps" })) | Out-String | ConvertFrom-Json
$liste_regex = ((Get-Content (Get-ChildItem -Path (Get-Location) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "regex-ps" })) | Out-String | ConvertFrom-Json | Get-Member | Where-Object { $_.MemberType -match "NoteProperty"}).Name

# Récupération du chemin vers le dossier à blanchir
function get_path {
    return Read-Host -Prompt "Entrez le chemin vers le dossier/fichier à blanchir"
}
$path = get_path
if (-Not (Test-Path $path)) {
    Write-Error -Message "Le chemin $path n'existe pas, veuillez rentrer un chemin existant"
    $path = get_path
}

# Blanchissement des fichiers
Write-Output "Fichiers blanchis dans $path :"
# Lister les fichiers et dossiers de manière récursive
DIR -r  $path | % { 
    # Modifier uniquement les fichiers et pas les dossiers
    if ($_.PsIsContainer -eq $false) { 
        Write-Output "Working on : "(Get-Item $_.FullName | Resolve-Path -Relative)
        # Pour chaque entrée de la liste des regex génériques
        for ($i = 0; $i -lt $liste_regex.Length; $i+=1) {
            $key = $liste_regex[$i]
            $occurances = (((Get-Content $_.FullName) -match $regex.($key)) | Measure-Object -Line).Lines

            (Get-Content $_.FullName) -replace $regex.($key), ($key) | Set-Content $_.FullName

            Write-Output " => Replaced $occurances occurances of $key"
        }

        # Pour chaque entrée dans la liste des serveurs propre au réseau
        for ($i = 0; $i -lt $server_list.Length; $i+=1) {
            # Modifier les noms de serveur dans la liste
            $key = $server_list[$i]
            $occurances = (((Get-Content $_.FullName) -match $key) | Measure-Object -Line).Lines

            (Get-Content $_.FullName) -replace $key, [string]"SERVER_$i" | Set-Content $_.FullName

            Write-Output " => Replaced $occurances occurances of $key"
        }
        
    } 
}