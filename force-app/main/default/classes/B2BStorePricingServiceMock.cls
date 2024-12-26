@Istest
public class B2BStorePricingServiceMock {
    private String calloutName;
    private CalloutSetting__mdt settings;

    public B2BStorePricingServiceMock(String calloutName){
        this.calloutName = calloutName;
        this.settings = getCalloutSettings();
    }
    
    private CalloutSetting__mdt getCalloutSettings(){
        CalloutSetting__mdt settings = CalloutSetting__mdt.getInstance(calloutName);
        
        System.assertNotEquals(null, settings);
        
        return settings;
    }

    public String getSettingsEndpoint(){
        return settings.Endpoint__c;
    }

    public String getSettingsMethod(){
        return settings.Method__c;
    }

    public class Success implements HttpCalloutMock {
        B2BStorePricingServiceMock mock;

        public Success(String calloutName){
            this.mock = new B2BStorePricingServiceMock(calloutName);
        }

        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals(mock.getSettingsEndpoint(), request.getEndpoint());
            System.assertEquals(mock.getSettingsMethod(), request.getMethod());
    
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"pricebooks": [{"client_code": "CLC-Test","products": [{"sku": "SKU-Test","list_price": 60,"sales_price": 45}]}]}');
    
            return response; 
        }
    }

    public class Error implements HttpCalloutMock {
        B2BStorePricingServiceMock mock;

        public Error(String calloutName){
            this.mock = new B2BStorePricingServiceMock(calloutName);
        }

        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals(mock.getSettingsEndpoint(), request.getEndpoint());
            System.assertEquals(mock.getSettingsMethod(), request.getMethod());
    
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(500);
    
            return response; 
        }
    }
}