#Requires -Version 5.1
<#
.SYNOPSIS
    Eclipse Temurin LTS JDK Manager - A modern GUI for managing Java installations via winget

.DESCRIPTION
    This tool provides a graphical interface to:
    - Install/upgrade Eclipse Temurin LTS JDK versions (8, 11, 17, 21, 25)
    - Uninstall JDK versions
    - Set default JAVA_HOME and PATH
    - Check for available updates
    - View installation logs

.NOTES
    Author: Enhanced PowerShell GUI
    Version: 2.0
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# =========================================================
# CONFIGURATION
# =========================================================

$script:Config = @{
    BaseDir       = Join-Path $env:USERPROFILE "GravvlJDK\Temurin"
    DefaultFile   = $null  # Set after BaseDir
    LogFile       = $null  # Set after BaseDir
    AppName       = "Temurin LTS JDK Manager"
    AppVersion    = "2.0"
}
$script:Config.DefaultFile = Join-Path $script:Config.BaseDir "default_jdk.txt"
$script:Config.LogFile = Join-Path $script:Config.BaseDir "manager.log"

# LTS releases (Adoptium / Temurin via winget)
$script:LtsDefs = @(
    @{ Display = "Eclipse Temurin JDK 8 LTS";  Major = 8;  WingetId = "EclipseAdoptium.Temurin.8.JDK";  Folder = "8"  }
    @{ Display = "Eclipse Temurin JDK 11 LTS"; Major = 11; WingetId = "EclipseAdoptium.Temurin.11.JDK"; Folder = "11" }
    @{ Display = "Eclipse Temurin JDK 17 LTS"; Major = 17; WingetId = "EclipseAdoptium.Temurin.17.JDK"; Folder = "17" }
    @{ Display = "Eclipse Temurin JDK 21 LTS"; Major = 21; WingetId = "EclipseAdoptium.Temurin.21.JDK"; Folder = "21" }
    @{ Display = "Eclipse Temurin JDK 25 LTS"; Major = 25; WingetId = "EclipseAdoptium.Temurin.25.JDK"; Folder = "25" }
)

# Global state
$script:WingetAvailable = $false
$script:InstallQueue = @()
$script:InstallIndex = 0
$script:LtsItems = @()
$script:IsOperationRunning = $false

# =========================================================
# LOGGING
# =========================================================

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        $logDir = Split-Path $script:Config.LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $script:Config.LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging fails
    }
}

# =========================================================
# INITIALIZATION
# =========================================================

function Initialize-Environment {
    # Create base directory
    if (-not (Test-Path $script:Config.BaseDir)) {
        try {
            New-Item -ItemType Directory -Path $script:Config.BaseDir -Force | Out-Null
            Write-Log "Created base directory: $($script:Config.BaseDir)"
        }
        catch {
            Write-Log "Failed to create base directory: $_" -Level "ERROR"
        }
    }

    # Check winget availability
    $script:WingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)

    if (-not $script:WingetAvailable) {
        Write-Log "winget not found on system" -Level "WARN"
    }
    else {
        Write-Log "winget detected and available"
    }
}

# =========================================================
# XAML GUI DEFINITION
# =========================================================

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Temurin LTS JDK Manager"
        Height="580" Width="780"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E2E"
        ResizeMode="CanResizeWithGrip"
        MinHeight="500" MinWidth="650">

    <Window.Resources>
        <!-- Color Palette (Catppuccin Mocha inspired) -->
        <SolidColorBrush x:Key="BackgroundDark" Color="#1E1E2E"/>
        <SolidColorBrush x:Key="BackgroundMedium" Color="#313244"/>
        <SolidColorBrush x:Key="BackgroundLight" Color="#45475A"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#CDD6F4"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#A6ADC8"/>
        <SolidColorBrush x:Key="AccentBlue" Color="#89B4FA"/>
        <SolidColorBrush x:Key="AccentGreen" Color="#A6E3A1"/>
        <SolidColorBrush x:Key="AccentRed" Color="#F38BA8"/>
        <SolidColorBrush x:Key="AccentYellow" Color="#F9E2AF"/>
        <SolidColorBrush x:Key="AccentPeach" Color="#FAB387"/>

        <!-- Button Style -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource BackgroundMedium}"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BackgroundLight}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{StaticResource BackgroundLight}"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="{StaticResource AccentBlue}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{StaticResource AccentBlue}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Primary Action Button -->
        <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#3B5998"/>
            <Setter Property="BorderBrush" Value="#4A6BB5"/>
        </Style>

        <!-- Danger Button -->
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#5C3A3A"/>
            <Setter Property="BorderBrush" Value="#7A4A4A"/>
        </Style>

        <!-- ListBox Style -->
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="{StaticResource BackgroundMedium}"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BackgroundLight}"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>

        <!-- ListBoxItem Style -->
        <Style TargetType="ListBoxItem">
            <Setter Property="Padding" Value="12,10"/>
            <Setter Property="Margin" Value="2"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="0"
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{StaticResource BackgroundLight}"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#3B5998"/>
                                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource AccentBlue}"/>
                                <Setter TargetName="Bd" Property="BorderThickness" Value="1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ProgressBar Style -->
        <Style TargetType="ProgressBar">
            <Setter Property="Background" Value="{StaticResource BackgroundMedium}"/>
            <Setter Property="Foreground" Value="{StaticResource AccentBlue}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4">
                            <Grid>
                                <Border x:Name="PART_Track" CornerRadius="4"/>
                                <Border x:Name="PART_Indicator"
                                        Background="{TemplateBinding Foreground}"
                                        CornerRadius="4"
                                        HorizontalAlignment="Left"/>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="Temurin LTS JDK Manager"
                       FontSize="24"
                       FontWeight="Bold"
                       Foreground="{StaticResource TextPrimary}"/>
            <TextBlock Text="Manage Eclipse Temurin LTS Java Development Kits via winget"
                       FontSize="13"
                       Foreground="{StaticResource TextSecondary}"
                       Margin="0,4,0,0"/>
        </StackPanel>

        <!-- Info Bar -->
        <Border Grid.Row="1"
                Background="{StaticResource BackgroundMedium}"
                CornerRadius="6"
                Padding="12,8"
                Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="InfoPath"
                           Text="Install location: Loading..."
                           Foreground="{StaticResource TextSecondary}"
                           FontSize="12"
                           VerticalAlignment="Center"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Ellipse x:Name="WingetIndicator"
                             Width="10" Height="10"
                             Fill="{StaticResource AccentGreen}"
                             Margin="0,0,6,0"/>
                    <TextBlock x:Name="WingetStatus"
                               Text="winget: Ready"
                               Foreground="{StaticResource TextSecondary}"
                               FontSize="12"
                               VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- JDK List -->
        <Border Grid.Row="2"
                Background="{StaticResource BackgroundMedium}"
                CornerRadius="8"
                Padding="4">
            <ListBox x:Name="VersionList"
                     BorderThickness="0"
                     Background="Transparent"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <!-- Version Icon/Badge -->
                            <Border Grid.Column="0"
                                    Background="#3B5998"
                                    CornerRadius="4"
                                    Width="50" Height="50"
                                    Margin="0,0,12,0">
                                <TextBlock Text="{Binding Major}"
                                           FontSize="20"
                                           FontWeight="Bold"
                                           Foreground="White"
                                           HorizontalAlignment="Center"
                                           VerticalAlignment="Center"/>
                            </Border>

                            <!-- Version Info -->
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="{Binding Name}"
                                           FontSize="14"
                                           FontWeight="SemiBold"
                                           Foreground="{StaticResource TextPrimary}"/>
                                <TextBlock Text="{Binding StatusText}"
                                           FontSize="12"
                                           Foreground="{StaticResource TextSecondary}"
                                           Margin="0,2,0,0"/>
                            </StackPanel>

                            <!-- Status Badges -->
                            <StackPanel Grid.Column="2"
                                        Orientation="Horizontal"
                                        VerticalAlignment="Center">
                                <Border x:Name="DefaultBadge"
                                        Background="{StaticResource AccentGreen}"
                                        CornerRadius="3"
                                        Padding="8,4"
                                        Margin="4,0"
                                        Visibility="{Binding DefaultVisibility}">
                                    <TextBlock Text="DEFAULT"
                                               FontSize="10"
                                               FontWeight="Bold"
                                               Foreground="#1E1E2E"/>
                                </Border>
                                <Border Background="{Binding StatusColor}"
                                        CornerRadius="3"
                                        Padding="8,4"
                                        Margin="4,0">
                                    <TextBlock Text="{Binding StatusBadge}"
                                               FontSize="10"
                                               FontWeight="Bold"
                                               Foreground="#1E1E2E"/>
                                </Border>
                            </StackPanel>
                        </Grid>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>
        </Border>

        <!-- Button Panel -->
        <WrapPanel Grid.Row="3"
                   HorizontalAlignment="Center"
                   Margin="0,12,0,8">
            <Button x:Name="BtnInstall"
                    Content="Install / Upgrade"
                    Style="{StaticResource PrimaryButton}"
                    ToolTip="Install or upgrade the selected JDK (Ctrl+I)"/>
            <Button x:Name="BtnUninstall"
                    Content="Uninstall"
                    Style="{StaticResource DangerButton}"
                    ToolTip="Uninstall the selected JDK (Ctrl+U)"/>
            <Button x:Name="BtnDefault"
                    Content="Set as Default"
                    Style="{StaticResource ModernButton}"
                    ToolTip="Set the selected JDK as default JAVA_HOME (Ctrl+D)"/>
            <Button x:Name="BtnInstallAll"
                    Content="Install All Missing"
                    Style="{StaticResource ModernButton}"
                    ToolTip="Install all LTS versions that are not yet installed"/>
            <Button x:Name="BtnRefresh"
                    Content="Refresh"
                    Style="{StaticResource ModernButton}"
                    ToolTip="Refresh the JDK list (F5)"/>
            <Button x:Name="BtnOpenFolder"
                    Content="Open Folder"
                    Style="{StaticResource ModernButton}"
                    ToolTip="Open the JDK installation folder in Explorer"/>
            <Button x:Name="BtnViewLog"
                    Content="View Log"
                    Style="{StaticResource ModernButton}"
                    ToolTip="View the application log file"/>
        </WrapPanel>

        <!-- Progress Section -->
        <StackPanel Grid.Row="4" Margin="0,4,0,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ProgressBar x:Name="ProgressBar"
                             Minimum="0" Maximum="100" Value="0"
                             VerticalAlignment="Center"/>
                <TextBlock x:Name="ProgressText"
                           Grid.Column="1"
                           Text="0%"
                           Foreground="{StaticResource TextSecondary}"
                           FontSize="12"
                           Margin="8,0,0,0"
                           VerticalAlignment="Center"
                           MinWidth="40"/>
            </Grid>
        </StackPanel>

        <!-- Status Bar -->
        <Border Grid.Row="5"
                Background="{StaticResource BackgroundMedium}"
                CornerRadius="6"
                Padding="12,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="Status"
                           Text="Ready"
                           Foreground="{StaticResource TextPrimary}"
                           FontSize="12"
                           TextWrapping="Wrap"
                           VerticalAlignment="Center"/>
                <TextBlock x:Name="VersionLabel"
                           Grid.Column="1"
                           Text="v2.0"
                           Foreground="{StaticResource TextSecondary}"
                           FontSize="11"
                           VerticalAlignment="Center"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# =========================================================
# GUI INITIALIZATION
# =========================================================

try {
    [xml]$xamlDoc = $xaml
    $reader = New-Object System.Xml.XmlNodeReader $xamlDoc
    $Window = [System.Windows.Markup.XamlReader]::Load($reader)
}
catch {
    [System.Windows.MessageBox]::Show(
        "Failed to load GUI: $($_.Exception.Message)",
        "Error",
        "OK",
        "Error"
    ) | Out-Null
    exit 1
}

# Get named elements
$VersionList = $Window.FindName("VersionList")
$BtnInstall = $Window.FindName("BtnInstall")
$BtnUninstall = $Window.FindName("BtnUninstall")
$BtnDefault = $Window.FindName("BtnDefault")
$BtnInstallAll = $Window.FindName("BtnInstallAll")
$BtnRefresh = $Window.FindName("BtnRefresh")
$BtnOpenFolder = $Window.FindName("BtnOpenFolder")
$BtnViewLog = $Window.FindName("BtnViewLog")
$ProgressBar = $Window.FindName("ProgressBar")
$ProgressText = $Window.FindName("ProgressText")
$Status = $Window.FindName("Status")
$InfoPath = $Window.FindName("InfoPath")
$WingetIndicator = $Window.FindName("WingetIndicator")
$WingetStatus = $Window.FindName("WingetStatus")
$VersionLabel = $Window.FindName("VersionLabel")

# =========================================================
# HELPER FUNCTIONS
# =========================================================

function Get-DefaultPath {
    if (Test-Path $script:Config.DefaultFile) {
        try {
            $content = (Get-Content $script:Config.DefaultFile -ErrorAction Stop).Trim()
            if ($content -and (Test-Path $content)) {
                return $content
            }
        }
        catch {
            Write-Log "Error reading default file: $_" -Level "WARN"
        }
    }
    return $null
}

function Get-JavaVersion {
    param([string]$JavaExePath)

    if (-not (Test-Path $JavaExePath)) {
        return $null
    }

    try {
        $output = & $JavaExePath -version 2>&1
        if ($output -and $output.Count -gt 0) {
            $match = [regex]::Match($output[0], '"([\d\.\+\-_]+)"')
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }
    }
    catch {
        Write-Log "Error getting Java version from $JavaExePath : $_" -Level "WARN"
    }
    return "unknown"
}

function Update-UIState {
    param([bool]$OperationRunning)

    $script:IsOperationRunning = $OperationRunning

    $BtnInstall.IsEnabled = -not $OperationRunning
    $BtnUninstall.IsEnabled = -not $OperationRunning
    $BtnDefault.IsEnabled = -not $OperationRunning
    $BtnInstallAll.IsEnabled = -not $OperationRunning
    $BtnRefresh.IsEnabled = -not $OperationRunning

    if ($OperationRunning) {
        $Window.Cursor = [System.Windows.Input.Cursors]::Wait
    }
    else {
        $Window.Cursor = [System.Windows.Input.Cursors]::Arrow
        $ProgressBar.Value = 0
        $ProgressText.Text = "0%"
    }
}

function Update-Progress {
    param(
        [int]$Value,
        [string]$StatusMessage
    )

    $Window.Dispatcher.Invoke([action]{
        if ($Value -ge 0 -and $Value -le 100) {
            $ProgressBar.Value = $Value
            $ProgressText.Text = "$Value%"
        }
        if ($StatusMessage) {
            $Status.Text = $StatusMessage
        }
    })
}

function Build-LtsItems {
    $items = [System.Collections.ObjectModel.ObservableCollection[PSObject]]::new()
    $defaultPath = Get-DefaultPath

    foreach ($def in $script:LtsDefs) {
        $folder = Join-Path $script:Config.BaseDir $def.Folder
        $javaExe = Join-Path $folder "bin\java.exe"
        $installed = Test-Path $javaExe
        $javaVersion = ""

        if ($installed) {
            $javaVersion = Get-JavaVersion -JavaExePath $javaExe
        }

        $isDefault = $false
        if ($defaultPath) {
            try {
                $defaultNorm = [IO.Path]::GetFullPath($defaultPath).TrimEnd('\')
                $folderNorm = [IO.Path]::GetFullPath($folder).TrimEnd('\')
                $isDefault = $defaultNorm -eq $folderNorm
            }
            catch {
                # Path comparison failed
            }
        }

        # Build status text
        $statusText = if ($installed) {
            if ($javaVersion -and $javaVersion -ne "unknown") {
                "Version: $javaVersion"
            }
            else {
                "Installed"
            }
        }
        else {
            "Not installed"
        }

        # Status badge and color
        $statusBadge = if ($installed) { "INSTALLED" } else { "NOT INSTALLED" }
        $statusColor = if ($installed) { "#A6E3A1" } else { "#6C7086" }
        $defaultVisibility = if ($isDefault) { "Visible" } else { "Collapsed" }

        $item = [PSCustomObject]@{
            Display           = $def.Display
            Name              = $def.Display
            Major             = $def.Major
            WingetId          = $def.WingetId
            FolderName        = $def.Folder
            FolderPath        = $folder
            Installed         = $installed
            JavaVersion       = $javaVersion
            IsDefault         = $isDefault
            StatusText        = $statusText
            StatusBadge       = $statusBadge
            StatusColor       = $statusColor
            DefaultVisibility = $defaultVisibility
        }
        $items.Add($item)
    }

    return $items
}

function Refresh-VersionList {
    $script:LtsItems = Build-LtsItems
    $VersionList.ItemsSource = $script:LtsItems

    $defaultPath = Get-DefaultPath
    if ($defaultPath) {
        $Status.Text = "Default JAVA_HOME: $defaultPath"
    }
    else {
        $Status.Text = "No default JDK set. Select an installed JDK and click 'Set as Default'."
    }

    Write-Log "Refreshed JDK list"
}

function Get-SelectedItem {
    if ($null -eq $VersionList.SelectedItem) {
        $Status.Text = "Please select a JDK from the list first."
        return $null
    }
    return $VersionList.SelectedItem
}

# =========================================================
# CORE OPERATIONS
# =========================================================

function Set-DefaultJdk {
    param([Parameter(Mandatory = $true)] $Selection)

    $folder = $Selection.FolderPath
    $javaExe = Join-Path $folder "bin\java.exe"

    if (-not (Test-Path $javaExe)) {
        $Status.Text = "Cannot set as default: JDK is not installed. Install it first."
        Write-Log "Attempted to set non-installed JDK as default: $($Selection.Name)" -Level "WARN"
        return
    }

    try {
        # Save default to file
        Set-Content -Path $script:Config.DefaultFile -Value $folder -Encoding UTF8

        # Set user environment variables
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $folder, "User")

        # Update PATH
        $oldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if (-not $oldPath) { $oldPath = "" }

        # Remove any existing Temurin paths
        $parts = $oldPath -split ';' | Where-Object {
            $_ -and ($_ -notlike "$($script:Config.BaseDir)*")
        }

        # Add new JDK bin to front of PATH
        $newPath = (Join-Path $folder "bin") + ";" + ($parts -join ";")
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

        # Update current session
        $env:JAVA_HOME = $folder
        $env:PATH = $newPath

        $Status.Text = "Default JDK set to $($Selection.Name)"
        Write-Log "Set default JDK to: $($Selection.Name) at $folder"

        Refresh-VersionList
    }
    catch {
        $Status.Text = "Error setting default JDK: $($_.Exception.Message)"
        Write-Log "Error setting default JDK: $_" -Level "ERROR"
    }
}

function Start-WingetOperation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,  # "install" or "uninstall"
        [Parameter(Mandatory = $true)]
        $Selection,
        [bool]$QueueMode = $false
    )

    if (-not $script:WingetAvailable) {
        $Status.Text = "winget is not available. Please install App Installer from the Microsoft Store."
        return
    }

    $folder = $Selection.FolderPath

    # For install, ensure folder exists
    if ($Operation -eq "install" -and -not (Test-Path $folder)) {
        try {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
        catch {
            $Status.Text = "Failed to create directory: $($_.Exception.Message)"
            return
        }
    }

    Update-UIState -OperationRunning $true
    $operationText = if ($Operation -eq "install") { "Installing" } else { "Uninstalling" }
    $Status.Text = "$operationText $($Selection.Name)..."
    Write-Log "Starting $Operation for $($Selection.Name)"

    # Build winget arguments
    $wingetArgs = if ($Operation -eq "install") {
        "install --id `"$($Selection.WingetId)`" -e --accept-package-agreements --accept-source-agreements --silent --location `"$folder`""
    }
    else {
        "uninstall --id `"$($Selection.WingetId)`" -e --silent"
    }

    # Create background job
    $jobScript = {
        param($WingetArgs)

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        $psi.Arguments = $WingetArgs
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi

        try {
            [void]$process.Start()
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            return @{
                ExitCode = $process.ExitCode
                Output   = $stdout
                Error    = $stderr
            }
        }
        catch {
            return @{
                ExitCode = -1
                Output   = ""
                Error    = $_.Exception.Message
            }
        }
    }

    $job = Start-Job -ScriptBlock $jobScript -ArgumentList $wingetArgs

    # Create a timer to check job status
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)

    $progressValue = 5
    $timer.Tag = @{
        Job       = $job
        Selection = $Selection
        Operation = $Operation
        QueueMode = $QueueMode
        Progress  = $progressValue
    }

    $timer.Add_Tick({
        $context = $this.Tag
        $job = $context.Job

        if ($job.State -eq "Completed") {
            $this.Stop()

            $result = Receive-Job -Job $job
            Remove-Job -Job $job

            $Window.Dispatcher.Invoke([action]{
                $opText = if ($context.Operation -eq "install") { "Installation" } else { "Uninstallation" }

                if ($result.ExitCode -eq 0) {
                    Update-Progress -Value 100 -StatusMessage "$opText of $($context.Selection.Name) completed successfully."
                    Write-Log "$opText completed for $($context.Selection.Name)"
                }
                else {
                    $errorMsg = if ($result.Error) { $result.Error } else { "Exit code: $($result.ExitCode)" }
                    Update-Progress -Value 0 -StatusMessage "$opText failed for $($context.Selection.Name). $errorMsg"
                    Write-Log "$opText failed for $($context.Selection.Name): $errorMsg" -Level "ERROR"
                }

                # Clean up folder if uninstall succeeded
                if ($context.Operation -eq "uninstall" -and $result.ExitCode -eq 0) {
                    $folder = $context.Selection.FolderPath
                    if (Test-Path $folder) {
                        try {
                            Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                            Write-Log "Removed folder: $folder"
                        }
                        catch {
                            Write-Log "Failed to remove folder $folder : $_" -Level "WARN"
                        }
                    }
                }

                Update-UIState -OperationRunning $false
                Refresh-VersionList

                # Handle queue mode
                if ($context.QueueMode -and $script:InstallQueue.Count -gt 0) {
                    $script:InstallIndex++
                    if ($script:InstallIndex -lt $script:InstallQueue.Count) {
                        $next = $script:InstallQueue[$script:InstallIndex]
                        Start-WingetOperation -Operation "install" -Selection $next -QueueMode $true
                    }
                    else {
                        $Status.Text = "All queued installations completed."
                        $script:InstallQueue = @()
                        $script:InstallIndex = 0
                    }
                }
            })
        }
        elseif ($job.State -eq "Failed") {
            $this.Stop()
            Remove-Job -Job $job -Force

            $Window.Dispatcher.Invoke([action]{
                Update-Progress -Value 0 -StatusMessage "Operation failed unexpectedly."
                Update-UIState -OperationRunning $false
                Write-Log "Job failed for $($context.Selection.Name)" -Level "ERROR"
            })
        }
        else {
            # Still running - update progress
            $context.Progress = [Math]::Min($context.Progress + 3, 90)
            $this.Tag = $context

            $Window.Dispatcher.Invoke([action]{
                Update-Progress -Value $context.Progress -StatusMessage "$($context.Operation) in progress for $($context.Selection.Name)..."
            })
        }
    })

    $timer.Start()
}

function Start-InstallQueue {
    param([Parameter(Mandatory = $true)] $Items)

    $script:InstallQueue = @($Items)
    $script:InstallIndex = 0

    if ($script:InstallQueue.Count -eq 0) {
        $Status.Text = "All LTS JDKs are already installed."
        return
    }

    $Status.Text = "Starting installation of $($script:InstallQueue.Count) JDK(s)..."
    Write-Log "Starting queue installation for $($script:InstallQueue.Count) JDKs"

    $first = $script:InstallQueue[0]
    Start-WingetOperation -Operation "install" -Selection $first -QueueMode $true
}

# =========================================================
# EVENT HANDLERS
# =========================================================

$BtnInstall.Add_Click({
    $sel = Get-SelectedItem
    if ($null -ne $sel) {
        Start-WingetOperation -Operation "install" -Selection $sel
    }
})

$BtnUninstall.Add_Click({
    $sel = Get-SelectedItem
    if ($null -ne $sel) {
        if (-not $sel.Installed) {
            $Status.Text = "$($sel.Name) is not installed."
            return
        }

        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to uninstall $($sel.Name)?`n`nThis will remove the JDK from:`n$($sel.FolderPath)",
            "Confirm Uninstall",
            "YesNo",
            "Warning"
        )

        if ($result -eq "Yes") {
            Start-WingetOperation -Operation "uninstall" -Selection $sel
        }
    }
})

$BtnDefault.Add_Click({
    $sel = Get-SelectedItem
    if ($null -ne $sel) {
        Set-DefaultJdk -Selection $sel
    }
})

$BtnInstallAll.Add_Click({
    $missing = $script:LtsItems | Where-Object { -not $_.Installed }
    if ($missing -and $missing.Count -gt 0) {
        $result = [System.Windows.MessageBox]::Show(
            "This will install $($missing.Count) JDK version(s):`n`n$($missing.Name -join "`n")`n`nContinue?",
            "Install All Missing",
            "YesNo",
            "Question"
        )

        if ($result -eq "Yes") {
            Start-InstallQueue -Items $missing
        }
    }
    else {
        $Status.Text = "All LTS JDKs are already installed."
    }
})

$BtnRefresh.Add_Click({
    Refresh-VersionList
    $Status.Text = "JDK list refreshed."
})

$BtnOpenFolder.Add_Click({
    $sel = Get-SelectedItem
    $folderToOpen = if ($null -ne $sel -and (Test-Path $sel.FolderPath)) {
        $sel.FolderPath
    }
    else {
        $script:Config.BaseDir
    }

    if (Test-Path $folderToOpen) {
        Start-Process explorer.exe -ArgumentList $folderToOpen
    }
    else {
        $Status.Text = "Folder does not exist: $folderToOpen"
    }
})

$BtnViewLog.Add_Click({
    if (Test-Path $script:Config.LogFile) {
        Start-Process notepad.exe -ArgumentList $script:Config.LogFile
    }
    else {
        $Status.Text = "Log file not found. It will be created after the first operation."
    }
})

# Keyboard shortcuts
$Window.Add_KeyDown({
    param($sender, $e)

    if ($script:IsOperationRunning) { return }

    switch ($e.Key) {
        "F5" {
            Refresh-VersionList
            $Status.Text = "JDK list refreshed."
            $e.Handled = $true
        }
        "I" {
            if ($e.KeyboardDevice.Modifiers -eq "Control") {
                $sel = Get-SelectedItem
                if ($null -ne $sel) {
                    Start-WingetOperation -Operation "install" -Selection $sel
                }
                $e.Handled = $true
            }
        }
        "U" {
            if ($e.KeyboardDevice.Modifiers -eq "Control") {
                $BtnUninstall.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                $e.Handled = $true
            }
        }
        "D" {
            if ($e.KeyboardDevice.Modifiers -eq "Control") {
                $sel = Get-SelectedItem
                if ($null -ne $sel) {
                    Set-DefaultJdk -Selection $sel
                }
                $e.Handled = $true
            }
        }
    }
})

# Double-click to set as default
$VersionList.Add_MouseDoubleClick({
    $sel = Get-SelectedItem
    if ($null -ne $sel -and $sel.Installed) {
        Set-DefaultJdk -Selection $sel
    }
})

# Context menu
$contextMenu = New-Object System.Windows.Controls.ContextMenu

$menuInstall = New-Object System.Windows.Controls.MenuItem
$menuInstall.Header = "Install / Upgrade"
$menuInstall.Add_Click({
    $sel = Get-SelectedItem
    if ($null -ne $sel) {
        Start-WingetOperation -Operation "install" -Selection $sel
    }
})

$menuUninstall = New-Object System.Windows.Controls.MenuItem
$menuUninstall.Header = "Uninstall"
$menuUninstall.Add_Click({
    $BtnUninstall.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
})

$menuSetDefault = New-Object System.Windows.Controls.MenuItem
$menuSetDefault.Header = "Set as Default"
$menuSetDefault.Add_Click({
    $sel = Get-SelectedItem
    if ($null -ne $sel) {
        Set-DefaultJdk -Selection $sel
    }
})

$menuOpenFolder = New-Object System.Windows.Controls.MenuItem
$menuOpenFolder.Header = "Open Folder"
$menuOpenFolder.Add_Click({
    $sel = Get-SelectedItem
    if ($null -ne $sel -and (Test-Path $sel.FolderPath)) {
        Start-Process explorer.exe -ArgumentList $sel.FolderPath
    }
})

$contextMenu.Items.Add($menuInstall) | Out-Null
$contextMenu.Items.Add($menuUninstall) | Out-Null
$contextMenu.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
$contextMenu.Items.Add($menuSetDefault) | Out-Null
$contextMenu.Items.Add([System.Windows.Controls.Separator]::new()) | Out-Null
$contextMenu.Items.Add($menuOpenFolder) | Out-Null

$VersionList.ContextMenu = $contextMenu

# =========================================================
# INITIALIZATION AND RUN
# =========================================================

Initialize-Environment

# Update UI based on winget status
if ($script:WingetAvailable) {
    $WingetIndicator.Fill = [System.Windows.Media.Brushes]::LightGreen
    $WingetStatus.Text = "winget: Ready"
}
else {
    $WingetIndicator.Fill = [System.Windows.Media.Brushes]::Red
    $WingetStatus.Text = "winget: Not Found"

    [System.Windows.MessageBox]::Show(
        "winget is not installed or not found on PATH.`n`nPlease install 'App Installer' from the Microsoft Store to use this application.",
        "winget Not Found",
        "OK",
        "Warning"
    ) | Out-Null
}

$InfoPath.Text = "Install location: $($script:Config.BaseDir)"
$VersionLabel.Text = "v$($script:Config.AppVersion)"

Refresh-VersionList
Write-Log "Application started"

$Window.ShowDialog() | Out-Null

Write-Log "Application closed"
