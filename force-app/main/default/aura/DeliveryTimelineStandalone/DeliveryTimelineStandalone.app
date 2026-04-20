<!--
    True-fullscreen standalone host for deliveryProFormaTimeline.
    Accessed directly at /c/DeliveryTimelineStandalone.app (unnamespaced)
    or /<namespace>/DeliveryTimelineStandalone.app (namespaced). Renders
    as top-level page OUTSIDE /one/one.app, so no LEX chrome appears —
    the entire viewport is the gantt.

    Unlike DeliveryTimelineOut.app (extends ltng:outApp) which is a
    Lightning Out bootstrap target for VF embedding, this app is a
    standalone app you navigate to directly. `force:slds` injects SLDS
    styles globally so the LWC's lightning-* primitives render natively.

    The `c:` namespace is context-sensitive in Aura — it resolves to the
    package's own namespace when installed as a managed package, and to
    the custom (unnamespaced) namespace in scratch orgs. So `c:delivery
    ProFormaTimeline` renders the local package's LWC in both contexts
    without needing a CumulusCI namespace token (which can't be used as
    an XML element-name prefix anyway).
-->
<aura:application extends="force:slds" access="GLOBAL">
    <c:deliveryProFormaTimeline mode="fullscreen" />
</aura:application>
