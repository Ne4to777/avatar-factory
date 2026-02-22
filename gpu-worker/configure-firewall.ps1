# Configure Windows Firewall for Avatar Factory GPU Worker
# Opens TCP port 8001 for incoming connections

param(
    [ValidateSet("Add", "Remove", "Check")]
    [string]$Action = "Add",
    [int]$Port = 8001
)

. "$PSScriptRoot\lib\common.ps1"

$RULE_NAME = "Avatar Factory GPU Worker"

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-ErrorMsg "Firewall configuration requires administrator privileges"
    Restart-AsAdministrator -Arguments @("-Action", $Action, "-Port", $Port)
    exit
}

Write-Banner "Firewall Configuration"

switch ($Action) {
    "Add" {
        Write-Info "Adding firewall rule for port $Port..."

        $existingRule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue

        if ($existingRule) {
            Write-WarningMsg "Firewall rule already exists"
            Write-Info "Removing old rule..."
            try {
                Remove-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction Stop
            }
            catch {
                Write-ErrorMsg "Failed to remove existing rule: $_"
                exit 1
            }
        }

        try {
            $null = New-NetFirewallRule `
                -DisplayName $RULE_NAME `
                -Description "Allows incoming connections to Avatar Factory GPU Worker server" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort $Port `
                -Action Allow `
                -Profile Any `
                -Enabled True

            Write-Success "Firewall rule added successfully"
            Write-Info "Port $Port is now open for incoming connections"
        }
        catch {
            Write-ErrorMsg "Failed to add firewall rule: $_"
            exit 1
        }
    }

    "Remove" {
        Write-Info "Removing firewall rule..."

        $existingRule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue

        if ($existingRule) {
            try {
                Remove-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction Stop
                Write-Success "Firewall rule removed"
            }
            catch {
                Write-ErrorMsg "Failed to remove firewall rule: $_"
                exit 1
            }
        }
        else {
            Write-WarningMsg "Firewall rule not found"
        }
    }

    "Check" {
        Write-Info "Checking firewall rule..."

        $rule = Get-NetFirewallRule -DisplayName $RULE_NAME -ErrorAction SilentlyContinue

        if ($rule) {
            Write-Success "Firewall rule exists"
            Write-Host ""
            Write-Host "Rule Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($rule.DisplayName)"
            Write-Host "  Direction: $($rule.Direction)"
            Write-Host "  Action: $($rule.Action)"
            Write-Host "  Enabled: $($rule.Enabled)"

            $portFilter = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
            if ($portFilter) {
                Write-Host "  Port: $($portFilter.LocalPort)"
                Write-Host "  Protocol: $($portFilter.Protocol)"
            }
            Write-Host ""
        }
        else {
            Write-WarningMsg "Firewall rule not found"
            Write-Info "Run with -Action Add to create the rule"
        }
    }
}

exit 0
