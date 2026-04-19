<!--
    Lightning Out container for deliveryProFormaTimeline.
    Used by DeliveryGanttStandalone.page to embed the gantt in a
    no-chrome Visualforce page (showHeader=false).
    SLDS is loaded via <apex:slds /> in the VF page.
-->
<aura:application access="GLOBAL" extends="ltng:outApp">
    <aura:dependency resource="%%%NAMESPACE_OR_C%%%:deliveryProFormaTimeline" />
</aura:application>
