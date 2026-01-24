const fs = require('fs');
const path = require('path');

// ==========================================
// CONFIGURATION: The "Delivery" Namespace Refactor Map
// ==========================================
const ROOT_DIR = path.join(__dirname, 'force-app', 'main', 'default'); 

// 1. LWC Component Renames (Folder + Internal Files)
// Target: delivery__ghostRecorder
const LWC_RENAMES = [
    { old: 'deliveryGhostRecorder', new: 'ghostRecorder' },
    { old: 'deliveryHubSetup',      new: 'hubSetup' },
    { old: 'deliveryBudgetSummary', new: 'budgetSummary' },
    { old: 'deliveryCommentStream', new: 'commentStream' },
    { old: 'deliveryFileSender',    new: 'fileSender' },
    { old: 'manageDeliveryRequest', new: 'manageRequest' } 
];

// 2. File & Class Renames (Apex, Objects, Permissions)
// Target: delivery__GhostController, delivery__HubSender, etc.
const FILE_RENAMES = [
    // --- APEX CLASSES ---
    { old: 'DeliveryGhostController',        new: 'GhostController' },
    { old: 'DeliveryGhostControllerTest',    new: 'GhostControllerTest' },
    { old: 'DeliveryHubCommentIntake',       new: 'HubCommentIntake' },
    { old: 'DeliveryHubCommentIntakeTest',   new: 'HubCommentIntakeTest' },
    { old: 'DeliveryHubCommentSender',       new: 'HubCommentSender' },
    { old: 'DeliveryHubCommentSenderTest',   new: 'HubCommentSenderTest' },
    { old: 'DeliveryHubDashboardController', new: 'HubDashboardController' },
    { old: 'DeliveryHubDashboardControllerTest', new: 'HubDashboardControllerTest' },
    { old: 'DeliveryHubFileIntake',          new: 'HubFileIntake' },
    { old: 'DeliveryHubFileIntakeTest',      new: 'HubFileIntakeTest' },
    { old: 'DeliveryHubFileSender',          new: 'HubFileSender' },
    { old: 'DeliveryHubFileSenderTest',      new: 'HubFileSenderTest' },
    { old: 'DeliveryHubIntakeService',       new: 'HubIntakeService' },
    { old: 'DeliveryHubIntakeServiceTest',   new: 'HubIntakeServiceTest' },
    { old: 'DeliveryHubSender',              new: 'HubSender' },
    { old: 'DeliveryHubSenderTest',          new: 'HubSenderTest' },
    { old: 'DeliveryHubSettingsController',  new: 'HubSettingsController' },
    { old: 'DeliveryHubSettingsControllerTest', new: 'HubSettingsControllerTest' },
    { old: 'DeliveryHubSetupController',     new: 'HubSetupController' },
    { old: 'DeliveryHubSetupControllerTest', new: 'HubSetupControllerTest' },
    
    // --- OBJECTS & TABS ---
    // Target: delivery__Hub_Settings__c
    { old: 'Delivery_Hub_Settings__c',       new: 'Hub_Settings__c' },
    { old: 'Delivery_Hub_Settings',          new: 'Hub_Settings' }, 
    
    // --- PERMISSION SETS & GROUPS ---
    { old: 'DeliveryHubAdmin_App', new: 'HubAdmin_App' }, 
    { old: 'DeliveryHubApp',       new: 'HubApp' },       
    { old: 'DeliveryHubAdmin',     new: 'HubAdmin' },     
    { old: 'DeliveryHubUser',      new: 'HubUser' },      
];

// 3. Content String Replacements (Regex Generation)
const REPLACEMENTS = [];

// Helper: Camel/Pascal to Kebab (ghostRecorder -> c-ghost-recorder)
const toKebab = (str) => str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase();

// A. LWC Logic
LWC_RENAMES.forEach(item => {
    REPLACEMENTS.push({ find: item.old, replace: item.new });
    // HTML Tags: <c-delivery-ghost-recorder> -> <c-ghost-recorder>
    REPLACEMENTS.push({ find: `c-${toKebab(item.old)}`, replace: `c-${toKebab(item.new)}` });
    // Flexipage/XML References: c:deliveryGhostRecorder -> c:ghostRecorder
    REPLACEMENTS.push({ find: `c:${item.old}`, replace: `c:${item.new}` });
});

// B. File Logic
FILE_RENAMES.forEach(item => {
    // Standard text replacement (Apex class names, XML types)
    REPLACEMENTS.push({ find: item.old, replace: item.new });
    
    // Handle XML references for Permission Sets/Tabs/Apps
    REPLACEMENTS.push({ find: `<tab>${item.old}</tab>`, replace: `<tab>${item.new}</tab>` });
    
    // Handle specific Apex Constructor/Class definitions explicitly to be safe
    // Fix: public DeliveryGhostController() -> public GhostController()
    if (item.old.startsWith('Delivery')) {
        REPLACEMENTS.push({ find: `public ${item.old}`, replace: `public ${item.new}` });
        REPLACEMENTS.push({ find: `class ${item.old}`, replace: `class ${item.new}` });
    }
});

// ==========================================
// UTILITY FUNCTIONS
// ==========================================

function getAllFiles(dirPath, arrayOfFiles) {
    if (!fs.existsSync(dirPath)) return arrayOfFiles || [];
    
    const files = fs.readdirSync(dirPath);
    arrayOfFiles = arrayOfFiles || [];

    files.forEach(function(file) {
        if (fs.statSync(dirPath + "/" + file).isDirectory()) {
            arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles);
        } else {
            arrayOfFiles.push(path.join(dirPath, "/", file));
        }
    });
    return arrayOfFiles;
}

function processLwcRenames() {
    console.log('⚡ Processing LWC Folder Renames...');
    const lwcBaseDir = path.join(ROOT_DIR, 'lwc');
    
    if (fs.existsSync(lwcBaseDir)) {
        LWC_RENAMES.forEach(item => {
            const oldPath = path.join(lwcBaseDir, item.old);
            const newPath = path.join(lwcBaseDir, item.new);

            if (fs.existsSync(oldPath)) {
                // 1. Rename files INSIDE the folder first
                const files = fs.readdirSync(oldPath);
                files.forEach(file => {
                    const oldFilePath = path.join(oldPath, file);
                    const newFileName = file.replace(item.old, item.new);
                    const newFilePath = path.join(oldPath, newFileName);
                    
                    if (oldFilePath !== newFilePath) {
                        fs.renameSync(oldFilePath, newFilePath);
                    }
                });

                // 2. Rename the folder itself
                fs.renameSync(oldPath, newPath);
                console.log(`   ✅ Renamed LWC: ${item.old} -> ${item.new}`);
            }
        });
    } else {
        console.warn('   ⚠️ LWC Directory not found.');
    }
}

function processFileRenames() {
    console.log('📄 Processing File Renames (Apex, Objects, Permissions)...');
    const allFiles = getAllFiles(ROOT_DIR);
    
    FILE_RENAMES.forEach(rule => {
        allFiles.forEach(filePath => {
            const dir = path.dirname(filePath);
            const filename = path.basename(filePath);

            // Check if filename contains the old string (e.g., DeliveryHubSender.cls)
            if (filename.includes(rule.old)) {
                const newFilename = filename.replace(rule.old, rule.new);
                const newPath = path.join(dir, newFilename);
                
                // Safety check to ensure we don't accidentally overwrite if it exists
                if (!fs.existsSync(newPath)) {
                    fs.renameSync(filePath, newPath);
                    console.log(`   ✅ Renamed File: ${filename} -> ${newFilename}`);
                }
            }
        });
    });
}

function processContentReplacements() {
    console.log('🧠 Performing Content Search & Replace...');
    const allFiles = getAllFiles(ROOT_DIR);
    let modifiedCount = 0;

    allFiles.forEach(filePath => {
        // Skip binary files (images, static resources)
        const ext = path.extname(filePath).toLowerCase();
        if(['.png', '.jpg', '.jpeg', '.gif', '.zip', '.pdf'].includes(ext)) return;

        let content = fs.readFileSync(filePath, 'utf8');
        let fileChanged = false;

        REPLACEMENTS.forEach(rule => {
            // Escape special regex characters if present in the search string
            const escapedFind = rule.find.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const regex = new RegExp(escapedFind, 'g');
            
            if (regex.test(content)) {
                content = content.replace(regex, rule.replace);
                fileChanged = true;
            }
        });

        if (fileChanged) {
            fs.writeFileSync(filePath, content, 'utf8');
            modifiedCount++;
        }
    });

    console.log(`   🎉 Finished! Updated content in ${modifiedCount} files.`);
}

// ==========================================
// EXECUTION FLOW
// ==========================================
console.log('🚀 Starting "No Stutter" Refactor...');

try {
    // 1. Rename LWC folders and contents
    processLwcRenames();
    
    // 2. Rename Apex, Objects, Tabs, Perm Sets
    // (We re-scan files inside the function to ensure we catch files moved in step 1 if necessary)
    processFileRenames(); 
    
    // 3. Update the code inside the files
    processContentReplacements();
    
    console.log('✅ Refactor Complete.');
} catch (err) {
    console.error('❌ Error during refactor:', err);
}