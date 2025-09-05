public class TriggerControl {

    // This is the switch. When true, the async logic runs. When false, it's skipped.
    public static Boolean runAfterLogic = true;

    /**
     * @description Disables the after-trigger logic that enqueues jobs.
     */
    public static void disableAfterLogic() {
        runAfterLogic = false;
    }

    /**
     * @description Enables the after-trigger logic.
     */
    public static void enableAfterLogic() {
        runAfterLogic = true;
    }
}