List<delivery__DocumentTemplate__mdt> templates = [
    SELECT DeveloperName, MasterLabel
    FROM delivery__DocumentTemplate__mdt
];
System.debug(LoggingLevel.ERROR, 'Templates: ' + templates.size());
for (delivery__DocumentTemplate__mdt t : templates) {
    System.debug(LoggingLevel.ERROR, 'DEV=' + t.DeveloperName + ' | Label=' + t.MasterLabel);
}
