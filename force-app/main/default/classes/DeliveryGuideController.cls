/**
 * @description Controller for the Delivery Guide component.
 * Provides org context and Ghost Recorder installation detection.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryGuideController {

    private static final Set<String> GHOST_RECORDER_APP_NAMES = new Set<String>{
        'DeliveryHub', 'DeliveryHubAdmin',
        'delivery__DeliveryHub', 'delivery__DeliveryHubAdmin'
    };

    /**
     * @description Returns org context including domain URL, setup links, and a list
     * of all visible Lightning apps with Ghost Recorder installation status.
     * @return Map containing orgDomain, setupAppManager URL, and apps list
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getGuideContext() {
        Map<String, Object> ctx = new Map<String, Object>();

        String orgDomain = URL.getOrgDomainUrl().toExternalForm();
        ctx.put('orgDomain', orgDomain);
        ctx.put('setupAppManager', orgDomain + '/lightning/setup/NavigationMenus/home');

        List<Map<String, Object>> apps = new List<Map<String, Object>>();
        for (AppMenuItem item : [
            SELECT ApplicationId, Label, Name, Type
            FROM AppMenuItem
            WHERE Type = 'TabSet' AND IsVisible = true
            ORDER BY Label
        ]) {
            Map<String, Object> appInfo = new Map<String, Object>();
            appInfo.put('id', item.ApplicationId);
            appInfo.put('label', item.Label);
            appInfo.put('name', item.Name);
            appInfo.put('hasGhostRecorder', GHOST_RECORDER_APP_NAMES.contains(item.Name));
            apps.add(appInfo);
        }
        ctx.put('apps', apps);

        return ctx;
    }
}
