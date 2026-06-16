/**
 * Imperative Apex mock for DeliveryHoursAnalyticsController.getForecastItems.
 * The c-delivery-capacity-forecast LWC calls this imperatively (the method is
 * non-cacheable by design, so it cannot be @wired), so the mock is a plain
 * jest.fn the tests resolve/reject per case via mockResolvedValue /
 * mockRejectedValue. Defaults to resolving an empty list.
 */
const getForecastItems = jest.fn(() => Promise.resolve([]));
module.exports = { default: getForecastItems };
