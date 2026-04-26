import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import listProviders from "@salesforce/apex/%%%NAMESPACE_DOT%%%IntegrationProviderAdminController.listProviders";
import probeProvider from "@salesforce/apex/%%%NAMESPACE_DOT%%%IntegrationProviderAdminController.probeProvider";

/**
 * Integration Provider Admin · Phase 6 scaffold.
 *
 * Read-only table of registered providers + per-row "probe connection"
 * action. Full CRUD admin surface deferred per /mf/integration-framework-0426
 * Phase 6 risk R5 (real product, scoped separately).
 */
export default class IntegrationProviderAdmin extends LightningElement {
  providers = [];
  errorMessage = "";
  probing = {};

  @wire(listProviders)
  wiredProviders({ data, error }) {
    if (data) {
      this.providers = data;
      this.errorMessage = "";
    } else if (error) {
      this.providers = [];
      this.errorMessage = (error && error.body && error.body.message) || "Unknown error loading providers";
    }
  }

  get hasProviders() {
    return this.providers && this.providers.length > 0;
  }

  async handleProbe(event) {
    const devName = event.target.dataset.dev;
    if (!devName) return;
    this.probing = { ...this.probing, [devName]: true };
    try {
      const ok = await probeProvider({ providerDeveloperName: devName });
      this.dispatchEvent(
        new ShowToastEvent({
          title: ok ? "Connection healthy" : "Connection unhealthy",
          message: `${devName} returned ${ok ? "healthy" : "unhealthy"}.`,
          variant: ok ? "success" : "warning"
        })
      );
    } catch (e) {
      const msg = (e && e.body && e.body.message) || "probe failed";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Probe failed",
          message: `${devName}: ${msg}`,
          variant: "error"
        })
      );
    } finally {
      this.probing = { ...this.probing, [devName]: false };
    }
  }
}
