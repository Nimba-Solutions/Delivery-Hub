/**
 * Imperative Apex mock for DeliveryCapacityService.getTeamCapacity.
 * The c-delivery-capacity-forecast LWC calls this imperatively alongside
 * getForecastItems. Defaults to resolving null so the component exercises its
 * documented explicit fallback (3 developers × 160 h/mo); tests override via
 * mockResolvedValue with a configured TeamCapacity shape.
 */
const getTeamCapacity = jest.fn(() => Promise.resolve(null));
module.exports = { default: getTeamCapacity };
