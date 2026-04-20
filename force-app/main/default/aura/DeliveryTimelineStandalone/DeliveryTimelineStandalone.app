<!--
    True-fullscreen standalone host for deliveryProFormaTimeline.
    Accessed directly at /c/DeliveryTimelineStandalone.app (unnamespaced)
    or /<namespace>/DeliveryTimelineStandalone.app (namespaced). Renders
    as top-level page OUTSIDE /one/one.app, so no LEX chrome appears —
    the entire viewport is the gantt.

    Uses the CumulusCI %%%NAMESPACE_OR_C%%% token so `cci task run deploy`
    substitutes the actual namespace before deploy:
      unmanaged scratch → <c:deliveryProFormaTimeline/>
      namespaced scratch/managed package → <delivery:deliveryProFormaTimeline/>
    A literal `c:` prefix does NOT reliably resolve to the package namespace
    in Aura managed-package contexts (unlike LWC where `c:` always works).
    Note: `sf project deploy` does not perform this substitution and will
    fail with an XML parse error — always deploy via cci for this file.
-->
<aura:application extends="force:slds" access="GLOBAL">
    <%%%NAMESPACE_OR_C%%%:deliveryProFormaTimeline mode="fullscreen" />
</aura:application>
