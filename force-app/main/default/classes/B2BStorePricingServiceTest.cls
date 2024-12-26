@isTest
public class B2BStorePricingServiceTest {
    @testSetup
    static void testSetup(){
        Account acc = new Account(Name='Test Account', ExternalId__c = 'CLC-Test');
        Account acc2 = new Account(Name='Test Account No External Id');
        insert new List<Account>{acc, acc2};

        Product2 product = new Product2(Name = 'Test Product', ProductCode = 'testProduct1', IsActive = true, Description = 'Description', StockKeepingUnit = 'SKU-Test');
        Product2 product2 = new Product2(Name = 'Test Product 2', ProductCode = 'testProduct2', IsActive = true, Description = 'Description', StockKeepingUnit = 'SKU-Test2');
        insert new List<Product2>{product, product2};

        WebStore testWebStore = new WebStore(Name='TestWebStore');
        insert testWebStore;
    }

    @isTest
    static void processPriceTest(){
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1]; 
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 WHERE Name='Test Product' LIMIT 1];
        
        commercestorepricing.PricingRequestItem requestItem = new commercestorepricing.PricingRequestItem(product.Id);
        commercestorepricing.PricingRequest productPriceRequest = new commercestorepricing.PricingRequest();
        productPriceRequest.setWebStoreId(webStore.Id);
        productPriceRequest.setEffectiveAccountId(acc.Id);
        productPriceRequest.addPricingRequestItem(requestItem);

        Test.setMock(HttpCalloutMock.class, new B2BStorePricingServiceMock.Success('B2BStorePriceBooks'));
        Test.startTest();
        
        B2BStorePricingService pricingService = new B2BStorePricingService();
        commercestorepricing.PricingResponse response = pricingService.processPrice(productPriceRequest);

        System.assert(response.isSuccess(), 'Pricing Response is not success');
        System.assertEquals(1, response.getPricingResponseItems().size(), 'Pricing Response Items size is empty');
        checkResponseItems(response);
        Test.stopTest();
    }

    @isTest
    static void processPriceServerErrorTest(){
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1]; 
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 WHERE Name='Test Product' LIMIT 1];
        
        Cache.SessionPartition cachePartition = Cache.Session.getPartition('B2BStorePricingCache');

        if(cachePartition.contains('b2bStorePricebooks')){
            cachePartition.remove(B2BStorePricebookCache.class, 'b2bStorePricebooks');
        }

        commercestorepricing.PricingRequestItem requestItem = new commercestorepricing.PricingRequestItem(product.Id);
        commercestorepricing.PricingRequest productPriceRequest = new commercestorepricing.PricingRequest();
        productPriceRequest.setWebStoreId(webStore.Id);
        productPriceRequest.setEffectiveAccountId(acc.Id);
        productPriceRequest.addPricingRequestItem(requestItem);

        Test.setMock(HttpCalloutMock.class, new B2BStorePricingServiceMock.Error('B2BStorePriceBooks'));
        Test.startTest();
        
        Boolean errorThrown = false;

        try {
            B2BStorePricingService pricingService = new B2BStorePricingService();
            commercestorepricing.PricingResponse response = pricingService.processPrice(productPriceRequest);
        } catch (Exception e) {
            errorThrown = true;
        }

        Test.stopTest();

        System.assert(errorThrown, 'An error should be thrown when the callout to the external service fails.');
    }

    @isTest
    static void processPriceNoCustomerCodeTest(){
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account No External Id' LIMIT 1]; 
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 WHERE Name='Test Product' LIMIT 1];
        
        commercestorepricing.PricingRequestItem requestItem = new commercestorepricing.PricingRequestItem(product.Id);
        commercestorepricing.PricingRequest productPriceRequest = new commercestorepricing.PricingRequest();
        productPriceRequest.setWebStoreId(webStore.Id);
        productPriceRequest.setEffectiveAccountId(acc.Id);
        productPriceRequest.addPricingRequestItem(requestItem);

        Test.setMock(HttpCalloutMock.class, new B2BStorePricingServiceMock.Success('B2BStorePriceBooks'));
        Test.startTest();
        
        Boolean errorThrown = false;
        
        try {
            B2BStorePricingService pricingService = new B2BStorePricingService();
            commercestorepricing.PricingResponse response = pricingService.processPrice(productPriceRequest);
        } catch (B2BStorePricingService.B2BStorePricingServiceException e) {
            errorThrown = true;
        }

        Test.stopTest();

        System.assert(errorThrown, 'An error should be thrown when the account external id is null.');
    }

    @isTest
    static void processPriceNoPricesTest(){
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1]; 
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        Map<Id, Product2> products = new Map<Id,Product2>([SELECT Id, StockKeepingUnit FROM Product2]);
        
        commercestorepricing.PricingRequest productPriceRequest = new commercestorepricing.PricingRequest();
        productPriceRequest.setWebStoreId(webStore.Id);
        productPriceRequest.setEffectiveAccountId(acc.Id);

        for (Product2 product : products.values()) {
            commercestorepricing.PricingRequestItem requestItem = new commercestorepricing.PricingRequestItem(product.Id);
            productPriceRequest.addPricingRequestItem(requestItem);
        }

        Test.setMock(HttpCalloutMock.class, new B2BStorePricingServiceMock.Success('B2BStorePriceBooks'));
        Test.startTest();
        B2BStorePricingService pricingService = new B2BStorePricingService();
        commercestorepricing.PricingResponse response = pricingService.processPrice(productPriceRequest);

        System.assert(response.isSuccess(), 'Pricing Response is not success');
        System.assertEquals(2, response.getPricingResponseItems().size(), 'Pricing Response Items size is empty');

        commercestorepricing.PricingResponseItemCollection items = response.getPricingResponseItems();

        for(Integer i = 0; i < items.size(); i++){
            commercestorepricing.PricingResponseItem responseItem = items.get(i);
            Product2 product = products.get(responseItem.getProductId());
            
            if(product.StockKeepingUnit == 'SKU-Test2'){
                System.assert(!responseItem.isSuccess(), 'Pricing Response Item is success');
            }
        }

        Test.stopTest();
    }

    @isTest
    static void processPriceCacheTest(){
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1]; 
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 WHERE Name='Test Product' LIMIT 1];
        
        Cache.SessionPartition cachePartition = Cache.Session.getPartition('B2BStorePricingCache');

        if(cachePartition.contains('b2bStorePricebooks')){
            cachePartition.remove(B2BStorePricebookCache.class, 'b2bStorePricebooks');
        }

        commercestorepricing.PricingRequestItem requestItem = new commercestorepricing.PricingRequestItem(product.Id);
        commercestorepricing.PricingRequest productPriceRequest = new commercestorepricing.PricingRequest();
        productPriceRequest.setWebStoreId(webStore.Id);
        productPriceRequest.setEffectiveAccountId(acc.Id);
        productPriceRequest.addPricingRequestItem(requestItem);

        Test.setMock(HttpCalloutMock.class, new B2BStorePricingServiceMock.Success('B2BStorePriceBooks'));
        Test.startTest();
        
        B2BStorePricingService pricingService = new B2BStorePricingService();
        commercestorepricing.PricingResponse response = pricingService.processPrice(productPriceRequest);
        commercestorepricing.PricingResponse response2 = pricingService.processPrice(productPriceRequest);
        commercestorepricing.PricingResponse response3 = pricingService.processPrice(productPriceRequest);
        
        System.assertEquals(1, Limits.getCallouts(), 'More than one callout made');
        
        Test.stopTest();

        List<commercestorepricing.PricingResponse> responses = new List<commercestorepricing.PricingResponse>{response, response2, response3};
        for(commercestorepricing.PricingResponse pricingResponse : responses){
            checkResponseItems(pricingResponse);
        }
    }

    private static void checkResponseItems(commercestorepricing.PricingResponse response){
        commercestorepricing.PricingResponseItemCollection items = response.getPricingResponseItems();

        for(Integer i = 0; i < items.size(); i++){
            commercestorepricing.PricingResponseItem responseItem = items.get(i);
            System.assert(responseItem.isSuccess(), 'Pricing Response Item is not success');
        }
    }

}