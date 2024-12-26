public with sharing class B2BStorePricingCallout {
    private final Integer SUCCESS_CODE = 200;
    private final String CALLOUT_NAME = 'B2BStorePriceBooks';
    private String endpoint;
    private String method;

    public B2BStorePricingCallout() {
        getCalloutSettings();
    }

    private CalloutSetting__mdt getCalloutSettings(){
        CalloutSetting__mdt settings = CalloutSetting__mdt.getInstance(CALLOUT_NAME);
        
        if(settings == null){
            throw new B2BStorePricingCalloutException('Custom Metadata settings missing for B2BStorePricingCallout');
        }
        
        endpoint = settings.Endpoint__c;
        method = settings.Method__c;

        return settings;
    }

    public B2BStorePricingResponse getPricebooks() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint(endpoint);
        request.setMethod(method);
        HttpResponse response = http.send(request);

        if (response.getStatusCode() != SUCCESS_CODE) {
            throw new B2BStorePricingCalloutException('There was a problem with the request. Error: ' + response.getStatusCode());
        }

        B2BStorePricingResponse resultsFromExternalService = (B2BStorePricingResponse) JSON.deserialize(response.getBody(), B2BStorePricingResponse.class);
        return resultsFromExternalService;
    }
    
    public class B2BStorePricingResponse{
        public List<ExternalPricebook> pricebooks;
    }
    
    public class ExternalPricebook {
        public String client_code;
        public List<ProductsPrices> products;
    }
    
    public class ProductsPrices {
        public String sku;
        public Decimal list_price;
        public Decimal sales_price;
    }

    public class B2BStorePricingCalloutException extends Exception {}
}