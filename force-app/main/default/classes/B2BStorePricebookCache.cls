public class B2BStorePricebookCache implements Cache.CacheBuilder{
    private final String SESSION_PARTITION_NAME = 'B2BStorePricingCache';
    
    public Object doLoad(String key){
        B2BStorePricingCallout callout = new B2BStorePricingCallout();

        return callout.getPricebooks();
    }

    public Cache.SessionPartition getCachePartition(){
        return Cache.Session.getPartition(SESSION_PARTITION_NAME);
    }
}