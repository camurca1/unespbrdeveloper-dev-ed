@isTest
public class B2BStorePricingServiceTest {
    @testSetup
    static void testSetup(){
        Account acc = new Account(Name='Test Account', ExternalId__c = 'CLC-Test');
        Account acc2 = new Account(Name='Test Account No External Id');
        Account acc3 = new Account(Name='Test Account 2', ExternalId__c = 'CLC-Test2');
        insert new List<Account>{acc, acc2, acc3};

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
    static void processPriceMultipleAccountsTest(){
        Account acc = [SELECT Id FROM Account WHERE Name='Test Account' LIMIT 1]; 
        Account acc2 = [SELECT Id FROM Account WHERE Name='Test Account 2' LIMIT 1]; 
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 WHERE Name='Test Product' LIMIT 1];
        Map<String, Account> accById = new Map<String, Account>{acc.Id => acc, acc2.Id => acc2};
        
        commercestorepricing.PricingRequestItem requestItem = new commercestorepricing.PricingRequestItem(product.Id);
        commercestorepricing.PricingRequest accProductPriceRequest = new commercestorepricing.PricingRequest();
        accProductPriceRequest.setWebStoreId(webStore.Id);
        accProductPriceRequest.setEffectiveAccountId(acc.Id);
        accProductPriceRequest.addPricingRequestItem(requestItem);
        
        commercestorepricing.PricingRequest acc2ProductPriceRequest = new commercestorepricing.PricingRequest();
        acc2ProductPriceRequest.setWebStoreId(webStore.Id);
        acc2ProductPriceRequest.setEffectiveAccountId(acc2.Id);
        acc2ProductPriceRequest.addPricingRequestItem(requestItem);
        
        Test.setMock(HttpCalloutMock.class, new B2BStorePricingServiceMock.Success('B2BStorePriceBooks'));
        Test.startTest();
        
        B2BStorePricingService pricingService = new B2BStorePricingService();
        commercestorepricing.PricingResponse accResponse = pricingService.processPrice(accProductPriceRequest);
        commercestorepricing.PricingResponse acc2Response = pricingService.processPrice(acc2ProductPriceRequest);

        Map<String, commercestorepricing.PricingResponse> responseByClientCode = new Map<String, commercestorepricing.PricingResponse>{
            'CLC-Test' => accResponse,
            'CLC-Test2' => acc2Response
        };
        
        for(String clientCode : responseByClientCode.keySet()){
            commercestorepricing.PricingResponse pricingResponse = responseByClientCode.get(clientCode);

            System.assert(pricingResponse.isSuccess(), 'Pricing Response is not success');
            System.assertEquals(1, pricingResponse.getPricingResponseItems().size(), 'Pricing Response Items size is empty');

            checkResponseItems(pricingResponse);
            checkResponseItemsPrices(pricingResponse, clientCode);
        }

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

    private static void checkResponseItemsPrices(commercestorepricing.PricingResponse response, String client_code){
        commercestorepricing.PricingResponseItemCollection items = response.getPricingResponseItems();

        for(Integer i = 0; i < items.size(); i++){
            commercestorepricing.PricingResponseItem responseItem = items.get(i);
            System.assert(responseItem.isSuccess(), 'Pricing Response Item is not success');
            
            Decimal expectedListPrice;
            Decimal expectedSalePrice;
            
            if (client_code == 'CLC-Test') {
                expectedListPrice = 60;
                expectedSalePrice = 45;
            }
            
            if (client_code == 'CLC-Test2') {
                expectedListPrice = 80;
                expectedSalePrice = 55;
            }


            System.assertEquals(expectedListPrice, responseItem.getListPrice(), 'List Price does not match expected');
            System.assertEquals(expectedSalePrice, responseItem.getNegotiatedPrice(), 'Negotiated Price does not match expected');
        }
    }

}