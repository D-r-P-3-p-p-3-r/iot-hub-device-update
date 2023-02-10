<#
.SYNOPSIS
Build the Device Update product.

.DESCRIPTION
Does all of the work to build the device update product, and provides additional support,
such as static checks and building documentation.

.EXAMPLE
PS> ./Scripts/Build.ps1 -Type Debug -BuildUnitTests -Install -Clean
#>
Param(
    # Deletes targets before building.
    [switch]$Clean,
    # Build type, e.g. Release, RelWithDebInfo, Debug.
    [string]$Type = 'Debug',
    # Should documentation be built?
    [switch]$BuildDocumentation,
    # Should unit tests be built?
    [switch]$BuildUnitTests,
    # Should deployment package be built?
    [switch]$BuildPackages,
    # Output directory. Default is {git_root}/out
    [string]$OutputDirectory = "$(git.exe rev-parse --show-toplevel)/out",
    # Logging library to use
    [string]$LogLib = 'zlog',
    # Log folder to use for DU logs
    # TODO(JeffMill): Change this when folder structure determined.
    [string]$LogDir = '/var/log/adu',
    # Install the product locally
    [switch]$Install
)

function Show-Warning {
    Param([Parameter(mandatory = $true, position = 0)][string]$Message)
    Write-Host -ForegroundColor Yellow -NoNewline 'Warning:'
    Write-Host " $Message"
}

function Show-Error {
    Param([Parameter(mandatory = $true, position = 0)][string]$Message)
    Write-Host -ForegroundColor Red -NoNewline 'Error:'
    Write-Host " $Message"
}

function Show-Header {
    Param([Parameter(mandatory = $true, position = 0)][string]$Message)
    $sep = ":{0}:" -f (' ' * ($Message.Length + 2))
    Write-Host -ForegroundColor DarkYellow -BackgroundColor DarkBlue $sep
    Write-Host -ForegroundColor White -BackgroundColor DarkBlue ("  {0}  " -f $Message)
    Write-Host -ForegroundColor DarkYellow -BackgroundColor DarkBlue $sep
    ''
}

function Show-Bullet {
    Param([Parameter(mandatory = $true, position = 0)][string]$Message)
    Write-Host -ForegroundColor Blue -NoNewline '*'
    Write-Host " $Message"
}

function Show-CMakeErrors {
    Param([string[]]$BuildOutput)

    $regex = 'CMake Error at (?<File>.+):(?<Line>\d+)\s+\((?<Description>.+)\)'
    $result = $BuildOutput  | ForEach-Object {
        if ($_ -match $regex) {
            $matches
        }
    }
    if ($result.Count -ne 0) {
        Write-Host -ForegroundColor Red 'CMake errors:'

        $result | ForEach-Object {
            Show-Bullet  ("{0} ({1}): {2}" -f $_.File, $_.Line, $_.Description)
        }

        ''
    }
}

function Show-CompilerErrors {
    Param([string]$RootDir, [string[]]$BuildOutput)

    # Parse compiler errors
    # e.g. C:\wiot-s1\src\logging\zlog\src\zlog.c(13,10): fatal  error C1083: Cannot open include file: 'aducpal/unistd.h': No such file or directory [C:\wiot-s1\out\src\logging\zlog\zlog.vcxproj]
    $regex = '(?<File>.+)\((?<Line>\d+),(?<Column>\d+)\):.+error (?<Code>C\d+):\s+(?<Description>.+)\s+\[(?<Project>.+)\]'
    $result = $BuildOutput  | ForEach-Object {
        if ($_ -match $regex) {
            $matches
        }
    }
    if ($result.Count -ne 0) {
        Write-Host -ForegroundColor Red 'Compiler errors:'

        $result | ForEach-Object {
            Show-Bullet  ("{0} ({1},{2}): {3} [{4}]" -f $_.File.SubString($RootDir.Length + 1), $_.Line, $_.Column, $_.Description, (Split-Path $_.Project -Leaf))
        }

        ''
    }
}

function Show-LinkerErrors {
    Param([string]$RootDir, [string[]]$BuildOutput)

    # Parse linker errors

    $regex = '.+ error (?<Code>LNK\d+):\s+(?<Description>.+)\s+\[(?<Project>.+)\]'
    $result = $BuildOutput  | ForEach-Object {
        if ($_ -match $regex) {
            $matches
        }
    }
    if ($result.Count -ne 0) {
        Write-Host -ForegroundColor Red 'Linker errors:'

        $result | ForEach-Object {
            $project = $_.Project.SubString($RootDir.Length + 1)
            Show-Bullet  ("{0}: {1}" -f $project, $_.Description)
        }
        ''
    }

}

function Show-DoxygenErrors {
    Param([string]$RootDir, [string[]] $BuildOutput)

    # Parse Doxygen errors

    $regex = '\s*(?<File>.+?):(?<Line>\d+?): warning: (?<Message>.+)'
    $result = $BuildOutput | ForEach-Object {
        if ($_ -match $regex) {
            $matches
        }
    }
    if ($result.Count -ne 0) {
        Write-Host -ForegroundColor Red 'Doxygen errors:'

        $result | ForEach-Object {
            $file = $_.File.SubString($RootDir.Length + 1)
            Show-Bullet  ("{0} ({1}): {2}" -f $file, $_.Line, $_.Message)
        }
        ''
    }
}

$root_dir = git.exe rev-parse --show-toplevel

function Invoke-CopyFile {
    Param(
        [Parameter(mandatory = $true)][string]$Source,
        [Parameter(mandatory = $true)][string]$Destination)

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "$Source is not a file or doesn't exist"
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        throw "$Destination is not a folder"
    }

    $copyNeeded = $true

    $destinationFile = Join-Path $Destination (Split-Path $Source -Leaf)
    if (Test-Path $destinationFile -PathType Leaf) {
        $d_lwt = (Get-ChildItem $destinationFile).LastWriteTime
        $s_lwt = (Get-ChildItem $Source).LastWriteTime

        if ($d_lwt -ge $s_lwt) {
            # Destination is up to date or newer
            $copyNeeded = $false
        }
    }

    if ($copyNeeded) {
        "Copied: $Source => $Destination"
        # Force, in case destination is marked read-only
        Copy-Item -Force -LiteralPath $Source -Destination $Destination
    }
    else {
        "Same (or newer): $destinationFile"
    }
}


function Create-Adu-Folders {
    # TODO(JeffMill): [PAL] Temporary until paths are determined.

    mkdir -Force /etc/adu | Out-Null
    mkdir -Force /tmp/adu/testdata | Out-Null
    mkdir -Force /usr/bin | Out-Null
    mkdir -Force /usr/lib/adu | Out-Null
    mkdir -Force /usr/local/lib/adu | Out-Null
    mkdir -Force /usr/local/lib/systemd/system | Out-Null
    mkdir -Force /var/lib/adu | Out-Null
    mkdir -Force /var/lib/adu/diagnosticsoperationids | Out-Null
    mkdir -Force /var/lib/adu/downloads | Out-Null
    mkdir -Force /var/lib/adu/extensions/content_downloader | Out-Null
    mkdir -Force /var/lib/adu/extensions/sources | Out-Null
    mkdir -Force /var/lib/adu/sdc | Out-Null
}

function Register-Components {
    Param(
        [Parameter(Mandatory = $true)][string]$BinPath,
        [Parameter(Mandatory = $true)][string]$DataPath
    )

    Show-Header 'Registering components'

    # Launch agent to write config files
    # Based on postinst : register_reference_extensions

    $aduciotagent_path = $BinPath + '/AducIotAgent.exe'

    $adu_extensions_dir = "$DataPath/extensions"
    $adu_extensions_sources_dir = "$adu_extensions_dir/sources"

    #
    # contentDownloader
    #

    # curl content downlaoader not used on Windows.
    # /var/lib/adu/extensions/content_downloader/extension.json
    # $curl_content_downloader_file = 'curl_content_downloader.dll'
    # & $aduciotagent_path --register-extension "$adu_extensions_sources_dir/$curl_content_downloader_file" --extension-type contentDownloader --log-level 2

    # /var/lib/adu/extensions/content_downloader/extension.json
    $do_content_downloader_file = "$adu_extensions_sources_dir/deliveryoptimization_content_downloader.dll"
    & $aduciotagent_path --register-extension $do_content_downloader_file --extension-type contentDownloader --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }

    #
    # updateContentHandler
    #

    # /var/lib/adu/extensions/update_content_handlers/microsoft_script_1/content_handler.json
    $microsoft_script_1_handler_file = "$adu_extensions_sources_dir/microsoft_script_1.dll"
    & $aduciotagent_path --register-extension $microsoft_script_1_handler_file --extension-type updateContentHandler --extension-id 'microsoft/script:1' --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }

    # /var/lib/adu/extensions/update_content_handlers/microsoft_simulator_1/content_handler.json
    $microsoft_simulator_1_file = "$adu_extensions_sources_dir/microsoft_simulator_1.dll"
    & $aduciotagent_path --register-extension $microsoft_simulator_1_file --extension-type updateContentHandler --extension-id 'microsoft/simulator:1'
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }

    # /var/lib/adu/extensions/update_content_handlers/microsoft_steps_1/content_handler.json
    $microsoft_steps_1_file = "$adu_extensions_sources_dir/microsoft_steps_1.dll"
    & $aduciotagent_path --register-extension $microsoft_steps_1_file --extension-type updateContentHandler --extension-id 'microsoft/steps:1' --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }
    & $aduciotagent_path --register-extension $microsoft_steps_1_file --extension-type updateContentHandler --extension-id 'microsoft/update-manifest' --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }
    & $aduciotagent_path --register-extension $microsoft_steps_1_file --extension-type updateContentHandler --extension-id 'microsoft/update-manifest:4' --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }
    & $aduciotagent_path --register-extension $microsoft_steps_1_file --extension-type updateContentHandler --extension-id 'microsoft/update-manifest:5' --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }

    # microsoft/swupdate:1 not used on Windows.
    # /var/lib/adu/extensions/update_content_handlers/microsoft_swupdate_1/content_handler.json
    # $microsoft_simulator_1_file = "$adu_extensions_sources_dir/microsoft_swupdate_1.dll"
    # & $aduciotagent_path --register-extension $microsoft_simulator_1_file --extension-type updateContentHandler --extension-id 'microsoft/swupdate:1'
    # if ($LASTEXITCODE -ne 0) {
    #     Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    # }

    # /var/lib/adu/extensions/update_content_handlers/microsoft_wiot_1/content_handler.json
    $microsoft_wiot_1_handler_file = "$adu_extensions_sources_dir/microsoft_wiot_1.dll"
    & $aduciotagent_path --register-extension $microsoft_wiot_1_handler_file --extension-type updateContentHandler --extension-id 'microsoft/wiot:1'  --log-level 2
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Registration of '$do_content_downloader_file' failed: $LASTEXITCODE"
    }

    ''
}

function Install-DeliveryOptimization {
    Param(
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$Commit)

    Show-Header 'Building Delivery Optimization'

    "Branch: $Branch"
    "Folder: $Path"
    ''

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        mkdir $Path | Out-Null
    }
    Push-Location $Path

    # do_url=git@github.com:Microsoft/do-client.git
    $do_url = 'https://github.com/Microsoft/do-client.git'

    # Avoid "fatal: destination path '.' already exists and is not an empty directory."
    if (-not (Test-Path '.git' -PathType Container)) {
        git.exe clone --recursive --single-branch --branch $Branch --depth 1 $do_url .
    }

    if ($Commit) {
        git.exe checkout $Commit
    }

    $build_dir = 'cmake'

    # Note: bootstrap-windows.ps1 installs CMake and Python, but we already installed those,
    # so not calling that script.

    # Note: install-vcpkg-deps.ps1 uses vcpkg to install
    # gtest:x64-windows,boost-filesystem:x64-windows,boost-program-options:x64-windows
    # but we can't use "vcpkg install" as we're in vcpkg manifest mode.

    if (-not (Test-Path -LiteralPath $build_dir -PathType Container)) {
        mkdir $build_dir | Out-Null
    }

    # Bug 43044349: DO-client cmakefile not properly building correct type using cmake
    # -DCMAKE_BUILD_TYPE should ultimately be removed.
    $CMAKE_OPTIONS = '-DDO_BUILD_TESTS:BOOL=OFF', '-DDO_INCLUDE_SDK=ON', "-DCMAKE_BUILD_TYPE=$Type"
    cmake.exe -S . -B $build_dir @CMAKE_OPTIONS
    cmake.exe --build $build_dir --config $Type --parallel

    Pop-Location
    ''
}

function Install-Adu-Components {
    Param(
        [Parameter(Mandatory = $true)][string]$OutBinPath,
        [Parameter(Mandatory = $true)][string]$OutLibPath,
        [Parameter(Mandatory = $true)][string]$BinPath,
        [Parameter(Mandatory = $true)][string]$LibPath,
        [Parameter(Mandatory = $true)][string]$DataPath
    )
    # TODO(JeffMill): [PAL] Temporary until paths are determined.

    Show-Header 'Installing ADU Agent'

    Create-Adu-Folders

    # cmake --install should place binaries, but that's not working correctly.
    # TODO: Task 42936258: --install-prefix not working properly
    # & $cmake_bin --install $OutputDirectory --config $Type --verbose
    # $ret_val = $LASTEXITCODE
    # if ($ret_val -ne 0) {
    #     Write-Error "ERROR: CMake failed (Error $ret_val)"
    #     exit $ret_val
    # }
    # Workaround: Manually copy files...

    # contoso_component_enumerator
    # curl_content_downloader
    # microsoft_apt_1
    # microsoft_delta_download_handler

    Invoke-CopyFile "$OutBinPath/adu-shell.exe" $LibPath
    Invoke-CopyFile  "$OutBinPath/AducIotAgent.exe" $BinPath

    # IMPORTANT: Windows builds require these DLLS as well. Any way to build these statically?
    $dependencies = 'getopt', 'pthreadVC3d', 'libcrypto-1_1-x64'
    $dependencies | ForEach-Object {
        Invoke-CopyFile "$OutBinPath/$_.dll" $LibPath
        Invoke-CopyFile "$OutBinPath/$_.dll" $BinPath
    }

    # 'microsoft_swupdate_1', 'microsoft_swupdate_2'
    $extensions = 'deliveryoptimization_content_downloader', 'microsoft_script_1', 'microsoft_simulator_1', 'microsoft_steps_1', 'microsoft_wiot_1'
    $extensions | ForEach-Object {
        Invoke-CopyFile  "$OutLibPath/$_.dll" "$DataPath/extensions/sources"
    }

    if ($Type -eq 'Debug') {
        $pthread_dll = 'pthreadVC3d.dll'
    }
    else {
        $pthread_dll = 'pthreadVC3.dll'
    }
    Invoke-CopyFile "$OutBinPath/$pthread_dll" $LibPath
    Invoke-CopyFile "$OutBinPath/$pthread_dll" $BinPath

    ''

    # Healthcheck expects this file to be read-only.
    Set-ItemProperty -LiteralPath "$LibPath/adu-shell.exe" -Name IsReadOnly -Value $true

    Register-Components -BinPath $BinPath -DataPath $DataPath
}

function Create-DataFiles {
    Param(
        [Parameter(Mandatory = $true)][string]$DataFilePath
    )

    Show-Header 'Creating data files'

    "Data file path: $DataFilePath"
    ''

    #
    # $env:TEMP/du-simulator-data.json (SIMULATOR_DATA_FILE)
    #

    @'
{
    "isInstalled": {
        "*": {
            "resultCode": 901,
            "extendedResultCode": 0,
            "resultDetails": "simulated isInstalled"
        }
    },
    "download": {
        "*": {
            "resultCode": 500,
            "extendedResultCode": 0,
            "resultDetails": "simulated download"
        }
    },
    "install": {
        "resultCode": 600,
        "extendedResultCode": 0,
        "resultDetails": "simulated install"
    },
    "apply": {
        "resultCode": 700,
        "extendedResultCode": 0,
        "resultDetails": "simulated apply"
    }
}
'@ | Out-File -Encoding ASCII "$env:TEMP/du-simulator-data.json"

    #
    # /etc/adu/du-diagnostics-config.json
    #

    @'
{
    "logComponents": [
        {
            "componentName": "DU",
            "logPath": "/var/log/adu/"
        }
    ],
    "maxKilobytesToUploadPerLogPath": 5
}
'@ | Out-File -Encoding ASCII "$DataFilePath/du-diagnostics-config.json"

    #
    # /etc/adu/du-config.json
    #

    if (-not (Test-Path -LiteralPath "$DataFilePath/du-config.json" -PathType Leaf)) {
        @'
{
    "schemaVersion": "1.1",
    "aduShellTrustedUsers": [
        "adu",
        "do"
    ],
    "iotHubProtocol": "mqtt",
    "compatPropertyNames": "manufacturer,model",
    "manufacturer": "manufacturer",
    "model": "model",
    "agents": [
        {
            "name": "aduagent",
            "runas": "adu",
            "connectionSource": {
                "connectionType": "string",
                "connectionData": "[NOT_SPECIFIED]"
            },
            "$description": "manufacturer, model will be matched against update manifest 'compability' attributes",
            "manufacturer": "[NOT_SPECIFIED]",
            "model": "[NOT_SPECIFIED]"
        }
    ]
}
'@ | Out-File -Encoding ASCII "$DataFilePath/du-config.json"
    }

    if (Select-String -Pattern '[NOT_SPECIFIED]' -LiteralPath "$DataFilePath/du-config.json" -SimpleMatch) {
        Show-Warning "Need to edit connectionData, agents.manufacturer and/or agents.model in $DataFilePath/du-config.json"
        ''
        notepad.exe "$DataFilePath/du-config.json"
    }
}

#
#  _ __  __ _(_)_ _
# | '  \/ _` | | ' \
# |_|_|_\__,_|_|_||_|
#

if ($BuildDocumentation) {
    if (-not (Get-Command 'doxygen.exe' -CommandType Application -ErrorAction SilentlyContinue)) {
        Show-Error 'Can''t build documentation - doxygen is not installed or not in PATH.'
        exit 1
    }

    if (-not (Get-Command 'dot.exe' -CommandType Application -ErrorAction SilentlyContinue)) {
        Show-Error 'Can''t build documentation - dot (graphviz) is not installed or not in PATH.'
        exit 1
    }
}

# Set default log dir if not specified.
$runtime_dir = "$OutputDirectory/bin"
$library_dir = "$OutputDirectory/lib"
$cmake_bin = 'cmake.exe'

# TODO(JeffMill): This should be Windows when that plaform layer is ready.
$PlatformLayer = 'linux'

# Output banner
''
Show-Header 'Building ADU Agent'
Show-Bullet "Clean build: $Clean"
Show-Bullet "Documentation: $BuildDocumentation"
Show-Bullet "Platform layer: $PlatformLayer"
Show-Bullet "Build type: $Type"
Show-Bullet "Log directory: $LogDir"
Show-Bullet "Logging library: $LogLib"
Show-Bullet "Output directory: $OutputDirectory"
Show-Bullet "Build unit tests: $BuildUnitTests"
Show-Bullet "Build packages: $BuildPackages"
Show-Bullet "CMake: $cmake_bin"
Show-Bullet ("CMake version: {0}" -f (& $cmake_bin --version | Select-String  '^cmake version (.*)$').Matches.Groups[1].Value)
''

# Store options for CMAKE in an array
$CMAKE_OPTIONS = @(
    "-DADUC_BUILD_DOCUMENTATION:BOOL=$BuildDocumentation",
    "-DADUC_BUILD_UNIT_TESTS:BOOL=$BuildUnitTests",
    "-DADUC_BUILD_PACKAGES:BOOL=$BuildPackages",
    "-DADUC_LOG_FOLDER:STRING=$LogDir",
    "-DADUC_LOGGING_LIBRARY:STRING=$LogLib",
    "-DADUC_PLATFORM_LAYER:STRING=$PlatformLayer",
    "-DCMAKE_BUILD_TYPE:STRING=$Type",
    "-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON",
    "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY:STRING=$library_dir",
    "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY:STRING=$runtime_dir"
)

if (-not $Clean) {
    # -ErrorAction SilentlyContinue doesn't work on Select-String
    try {
        if (-not (Select-String 'CMAKE_PROJECT_NAME:' "$OutputDirectory/CMakeCache.txt")) {
            $Clean = $true
        }
    }
    catch {
        $Clean = $true
    }

    if ($Clean) {
        Show-Warning 'CMake cache seems out of date - forcing clean build.'
        ''
        $Clean = $true
    }
}

if ($Clean) {
    $decision = $Host.UI.PromptForChoice(
        'Clean Build',
        'Are you sure?',
        @(
            (New-Object Management.Automation.Host.ChoiceDescription '&Yes', 'Perform clean build'),
            (New-Object Management.Automation.Host.ChoiceDescription '&No', 'Stop build')
        ),
        1)
    if ($decision -ne 0) {
        exit 1
    }
    ''

    Show-Header 'Cleaning repo'

    if (Test-Path $OutputDirectory) {
        Show-Bullet $OutputDirectory
        Remove-Item -Force  -Recurse -LiteralPath $OutputDirectory
    }
    # TODO(JeffMill): Change when code changes paths (e.g. /tmp/adu/testdata)
    $folders = '/tmp', '/usr', '/var'
    $folders | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            Show-Bullet $_
            Remove-Item -Force  -Recurse -LiteralPath $_
        }
    }

    ''
}

mkdir -Path $OutputDirectory -Force | Out-Null

if ($Clean) {
    Show-Header 'Generating Makefiles'

    # show every find_package call (vcpkg specific):
    # $CMAKE_OPTIONS += '-DVCPKG_TRACE_FIND_PACKAGE:BOOL=ON'
    # Verbose output (very verbose, but useful!):
    # $CMAKE_OPTIONS += '--trace-expand'
    # See cmake dependencies (very verbose):
    # $CMAKE_OPTIONS += '--debug-output'
    # See compiler output at build time:
    # $CMAKE_OPTIONS += '-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON'
    # See library search output:
    # $CMAKE_OPTIONS += '-DCMAKE_EXE_LINKER_FLAGS=/VERBOSE:LIB'

    'CMAKE_OPTIONS:'
    $CMAKE_OPTIONS | ForEach-Object { Show-Bullet $_ }
    ''

    & $cmake_bin -S "$root_dir" -B $OutputDirectory @CMAKE_OPTIONS 2>&1 | Tee-Object -Variable cmake_output
    $ret_val = $LASTEXITCODE

    if ($ret_val -ne 0) {
        Write-Error "ERROR: CMake failed (Error $ret_val)"
        ''

        Show-CMakeErrors -BuildOutput $cmake_output

        exit $ret_val
    }

    ''
}

#
# Delivery Optimization
#
# TODO: Bug 43015575: do-client should be a submodule

# Reusing ".vcpkg-installed" folder ... why not?
$DoPath = "{0}/.vcpkg-installed/do-client" -f (git.exe rev-parse --show-toplevel)
Install-DeliveryOptimization -Type $Type -Path $DoPath -Branch 'v1.0.1'

Show-Header 'Building Product'

& $cmake_bin --build $OutputDirectory --config $Type --parallel 2>&1 | Tee-Object -Variable build_output
$ret_val = $LASTEXITCODE
''

if ($BuildDocumentation) {
    Show-DoxygenErrors -RootDir $root_dir -BuildOutput $build_output
}

if ($ret_val -ne 0) {
    Write-Host -ForegroundColor Red "ERROR: Build failed (Error $ret_val)"
    ''

    Show-CMakeErrors -BuildOutput $build_output

    Show-CompilerErrors -RootDir $root_dir -BuildOutput $build_output

    Show-LinkerErrors -RootDir $root_dir -BuildOutput $build_output

    exit $ret_val
}

if ($ret_val -eq 0 -and $BuildPackages) {
    Show-Header 'Building Package'

    Show-Warning 'BuildPackages NYI'
}

if ($ret_val -eq 0 -and $Install) {
    Install-Adu-Components `
        -OutBinPath "$runtime_dir/$Type" -OutLibPath "$library_dir/$Type" `
        -BinPath '/usr/bin' -LibPath '/usr/lib/adu' -DataPath '/var/lib/adu'

    Create-DataFiles -DataFilePath '/etc/adu'

    if (-not (Test-Path '/tmp/adu/testdata' -PathType Container)) {
        ''
        Show-Warning 'Do clean build to copy test data to /tmp/adu/testdata'
    }
}

exit $ret_val

