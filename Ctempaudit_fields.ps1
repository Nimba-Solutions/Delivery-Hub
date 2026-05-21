$ErrorActionPreference = "Stop"

$baseDir = "C:\Projects\Delivery-Hub"
$fieldDir = "$baseDir\force-app\main\default\objects"

# Master-Detail fields (immutable, listed in FIELD_NAMING.md)
$masterDetailFields = @{
    "BountyClaim__c" = "WorkItemId__c"
    "DeliveryDocument__c" = "NetworkEntityId__c"
    "DeliveryTransaction__c" = "DocumentId__c"
    "DocumentAction__c" = "DocumentId__c"
    "PortalAccess__c" = "NetworkEntityId__c"
    "WorkItemComment__c" = "WorkItemId__c"
    "WorkLog__c" = "RequestId__c"
    "WorkRequest__c" = "WorkItemId__c"
}

# Custom Settings primitive allowlist
$customSettingsAllowedTypes = @("Text", "Number", "DateTime", "Date", "Checkbox", "Currency", "Email", "Percent", "Phone", "Url")

# Violation categories
$violations = @{
    "UrlWithTxtSuffix" = @()
    "PicklistWithoutPkSuffix" = @()
    "NumberWithoutNumberSuffix" = @()
    "LongTextAreaWithoutTxtSuffix" = @()
    "LookupWithoutLookupSuffix" = @()
    "ForbiddenCheckbox" = @()
    "CustomSettingsTypeViolation" = @()
    "FormulaReturnTypeMismatch" = @()
}

$newObjectsCompliance = @{
    "Feature__c" = @()
    "FeatureDefinition__mdt" = @()
    "FeatureDependency__c" = @()
    "FeatureToggleRequest__c" = @()
    "FeatureToggleApproval__c" = @()
    "OnboardingTrack__mdt" = @()
    "OnboardingLesson__mdt" = @()
    "OnboardingQuiz__mdt" = @()
    "OnboardingChecklistItem__mdt" = @()
    "OnboardingProgress__c" = @()
    "ScratchOrgInstance__c" = @()
    "DevLoopGuide__mdt" = @()
    "DatasetTemplate__c" = @()
    "DatasetTemplateAssignment__c" = @()
    "WatcherDigest__c" = @()
}

$totalFields = 0
$fieldsByObject = @{}

# Scan all field metadata files
Get-ChildItem -Path $fieldDir -Recurse -Filter "*.field-meta.xml" | ForEach-Object {
    $file = $_
    $totalFields++
    
    try {
        [xml]$fieldXml = Get-Content $file.FullName
        $fieldType = $fieldXml.CustomField.type
        $fieldApiName = $fieldXml.CustomField.fullName
        $objectName = $file.Directory.Parent.Name
        
        # Store field count per object
        if (-not $fieldsByObject[$objectName]) {
            $fieldsByObject[$objectName] = @{count = 0; violations = 0; fields = @()}
        }
        $fieldsByObject[$objectName].count++
        $fieldsByObject[$objectName].fields += @{name = $fieldApiName; type = $fieldType}
        
        # Check for Checkbox fields (forbidden)
        if ($fieldType -eq "Checkbox") {
            $violations["ForbiddenCheckbox"] += @{object = $objectName; field = $fieldApiName}
            $fieldsByObject[$objectName].violations++
        }
        
        # Check URL fields with Txt suffix
        if ($fieldType -eq "Url" -and $fieldApiName -match "Txt__c$") {
            $violations["UrlWithTxtSuffix"] += @{object = $objectName; field = $fieldApiName; shouldBe = $fieldApiName -replace "Txt__c$", "__c"}
            $fieldsByObject[$objectName].violations++
        }
        
        # Check Picklist fields without Pk suffix
        if (($fieldType -eq "Picklist" -or $fieldType -eq "MultiselectPicklist") -and $fieldApiName -notmatch "Pk__c$") {
            $violations["PicklistWithoutPkSuffix"] += @{object = $objectName; field = $fieldApiName}
            $fieldsByObject[$objectName].violations++
        }
        
        # Check Number fields without Number suffix
        if ($fieldType -eq "Number" -and $fieldApiName -notmatch "Number__c$" -and $fieldApiName -notmatch "Sum__c$" -and $fieldApiName -notmatch "Pct__c$") {
            $violations["NumberWithoutNumberSuffix"] += @{object = $objectName; field = $fieldApiName}
            $fieldsByObject[$objectName].violations++
        }
        
        # Check LongTextArea fields without Txt suffix
        if ($fieldType -eq "LongTextArea" -and $fieldApiName -notmatch "Txt__c$") {
            $violations["LongTextAreaWithoutTxtSuffix"] += @{object = $objectName; field = $fieldApiName}
            $fieldsByObject[$objectName].violations++
        }
        
        # Check Lookup/Hierarchy fields without Lookup suffix (excluding Master-Detail)
        if (($fieldType -eq "Lookup" -or $fieldType -eq "Hierarchy") -and $fieldApiName -notmatch "Lookup__c$" -and $fieldApiName -notmatch "Id__c$") {
            $violations["LookupWithoutLookupSuffix"] += @{object = $objectName; field = $fieldApiName}
            $fieldsByObject[$objectName].violations++
        }
        
        # Check Formula fields return type
        if ($fieldType -eq "Formula") {
            $returnType = $fieldXml.CustomField.formula.returnType
            if ($returnType -eq "number" -and $fieldApiName -notmatch "Number__c$") {
                $violations["FormulaReturnTypeMismatch"] += @{object = $objectName; field = $fieldApiName; expected = "Number"; actual = $fieldApiName -replace ".*?([A-Za-z]+)__c$", '$1'}
                $fieldsByObject[$objectName].violations++
            }
            elseif ($returnType -eq "text" -and $fieldApiName -notmatch "Txt__c$") {
                $violations["FormulaReturnTypeMismatch"] += @{object = $objectName; field = $fieldApiName; expected = "Txt"; actual = $fieldApiName -replace ".*?([A-Za-z]+)__c$", '$1'}
                $fieldsByObject[$objectName].violations++
            }
        }
        
        # Check Custom Settings type restrictions
        if ($objectName -eq "DeliveryHubSettings__c") {
            if ($fieldType -notin $customSettingsAllowedTypes) {
                $violations["CustomSettingsTypeViolation"] += @{object = $objectName; field = $fieldApiName; type = $fieldType}
                $fieldsByObject[$objectName].violations++
            }
        }
        
        # Track new objects compliance
        if ($newObjectsCompliance.Contains($objectName)) {
            if ($fieldsByObject[$objectName].violations -gt 0) {
                # Already counted above
            }
        }
    }
    catch {
        Write-Host "Error processing $($file.FullName): $_"
    }
}

# Output results as JSON for parsing
$results = @{
    totalFields = $totalFields
    violations = $violations
    fieldsByObject = $fieldsByObject
}

$results | ConvertTo-Json -Depth 10 | Out-File "C:\temp\audit_results.json"
Write-Host "Audit complete. Results saved to C:\temp\audit_results.json"
