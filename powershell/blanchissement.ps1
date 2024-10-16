#############################################################
## Script de blanchissement des logs/fichiers              ##
## Fait par : Solene Poydenot                              ##
## Date création : 13/10/2024                              ##
## Date dernière modification :                            ##
#############################################################

# Définition des fonctions
function get_reseau {
    return Read-Host -Prompt "Entrez le nom du réseau concerné parmi $liste_reseau"
}
function get_path {
    return Read-Host -Prompt "Entrez le chemin vers le dossier/fichier à blanchir"
}
function test_path($path) {
    if (-Not (Test-Path $path)) {return $false}
}

# Début du script
Write-Output "--- Script de blanchissement des logs ---"

# Récupération de la liste spécifique au réseau
$liste_reseau = "sfr","redhat"

# Définition du fichier output
$date = (Get-Date -format "yyyyMMdd")
$output_path = ([string](Get-Location)+"\sortie_blanchissement\"+$date)
if (test_path($output_path) == $false) {mkdir $output_path}

$reseau = get_reseau
if (($liste_reseau -contains $reseau) -eq $false) {
    Write-Error -Message "Le reseau n'est pas dans la liste des réseaux disponibles ($liste_reseau)"
    $reseau = get_reseau
}

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
    Write-Error -Message "Le chemin $path n'existe pas, veuillez rentrer un chemin existant"
    $path = get_path
}

# Copie des fichiers à blanchir
Write-Output "Copie des fichiers à blanchir vers $output_path"
Try {
    Copy-Item -Recurse $path -Destination $output_path -errorAction stop
    Write-Host "Fichiers copiés."
} Catch {
    Write-Error "Il y a déjà ces dossiers dans $output_path"
    $choice = Read-Host -Prompt "Voulez-vous les écraser ? (o/N)"
    if ( $choice -eq "o") {
        Copy-Item -Recurse $path -Destination $output_path -Force
        Write-Host "Fichiers écrasés et copiés."
    } else {
        Write-Host "Sortie du programme de blanchissement."
        Break
    }
}

$output_path += "\"+$path.Split("\")[-1]

# Blanchissement des fichiers
Write-Output "Blanchissement des fichiers de $path dans $output_path :"

# Lister les fichiers et dossiers de manière récursive
Get-ChildItem -r  $output_path | ForEach-Object { 
    # Modifier uniquement les fichiers et pas les dossiers
    if ($_.PsIsContainer -eq $false) { 
        Write-Output "Working on : " ([string](Get-Item $_.FullName | Resolve-Path -Relative))

        # Pour chaque entrée de la liste des regex génériques
        for ($i = 0; $i -lt $liste_regex.Length; $i+=1) 
        {
            $key = $liste_regex[$i]
            $occurances = (((Get-Content $_.FullName) -match $regex.($key)) | Measure-Object -Line).Lines

            (Get-Content $_.FullName) -replace $regex.($key), ($key) | Set-Content $_.FullName

            Write-Output " => Replaced $occurances occurances of $key"
        }
        
    } 
}