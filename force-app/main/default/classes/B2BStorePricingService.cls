public with sharing class B2BStorePricingService extends commercestorepricing.PricingService {
	private final String CACHE_KEY = 'b2bStorePricebooks';
	
	public override commercestorepricing.PricingResponse processPrice(commercestorepricing.PricingRequest request) {
		Map<String, Product2> productBySKU = getProductBySKU(request);
		String clientCode = getClientCode(request.getEffectiveAccountId());
		B2BStorePricingCallout.B2BStorePricingResponse resultsFromExternalService = getPricebooks();
    	Map<String, PriceDataFromExternalService> pricesFromExternalService;

		pricesFromExternalService = populatePrice(resultsFromExternalService, clientCode);

	    commercestorepricing.PricingResponse response = buildResponse(productBySKU, pricesFromExternalService);

    	return response;
	}

	private Map<String, Product2> getProductBySKU(commercestorepricing.PricingRequest request){
		Set<String> productIds = getProductIds(request);
		List<Product2> products = getProducts(productIds);

		Map<String, Product2> productBySKU = new Map<String, Product2>();
	
		for(Product2 product : products) {
			productBySKU.put(product.StockKeepingUnit, product);
		}

		return productBySKU;
	}

	private Set<String> getProductIds(commercestorepricing.PricingRequest request) {
		Set<String> productIds = new Set<String>();
		commercestorepricing.PricingRequestItemCollection items = request.getPricingRequestItems();

		for (Integer i = 0; i < items.size(); i++) {
			commercestorepricing.PricingRequestItem item = items.get(i);
			productIds.add(item.getProductId());
		}

		return productIds;
	}

	private List<Product2> getProducts(Set<String> productIds){
		return [
				SELECT Id, StockKeepingUnit 
				FROM Product2 
				WHERE Id IN :productIds
				WITH SECURITY_ENFORCED
			 ];
	}

	private String getClientCode(String accountId) {
		String clientCode = [
			SELECT ExternalId__c
			FROM Account
			WHERE Id = :accountId
		].ExternalId__c;

		if(clientCode == null) {
			throw new B2BStorePricingServiceException('The account does not have an ExternalId__c value');
		}

		return clientCode; 
	}

	private B2BStorePricingCallout.B2BStorePricingResponse getPricebooks(){
		return (B2BStorePricingCallout.B2BStorePricingResponse) new B2BStorePricebookCache().getCachePartition().get(
			B2BStorePricebookCache.class, CACHE_KEY
		);
	}

	private Map<String, PriceDataFromExternalService> populatePrice(B2BStorePricingCallout.B2BStorePricingResponse resultsFromExternalService, String clientCode){
		Map<String, PriceDataFromExternalService> priceDataFromExternalServiceBySKU = new Map<String, PriceDataFromExternalService>();

		for(B2BStorePricingCallout.ExternalPricebook ePB: resultsFromExternalService.pricebooks){
			if(ePB.client_code != clientCode){
				continue;
			}

			for (B2BStorePricingCallout.ProductsPrices product : ePB.products) {
				priceDataFromExternalServiceBySKU.put(
					product.sku,
					new PriceDataFromExternalService(
						(Decimal) product.list_price,
						(Decimal) product.sales_price
					)
				);
			}
		}

		return priceDataFromExternalServiceBySKU;
 	 }

	 private commercestorepricing.PricingResponse buildResponse(Map<String, Product2> productBySKU, Map<String, PriceDataFromExternalService> pricesFromExternalService){
		commercestorepricing.PricingResponse response = new commercestorepricing.PricingResponse('BRL');
		
		for(String sku : productBySKU.keySet()){
			Product2 product = productBySKU.get(sku);

			if (hasNoPrices(pricesFromExternalService, sku)) {
				commercestorepricing.PricingResponseItem responseItem = new commercestorepricing.PricingResponseItem(
					product.Id,
					null,
					null,
					null,
					null
				);

				responseItem.setError(
					'No prices available for this product.',
					'Consulte disponibilidade.'
				);

				response.addPricingResponseItem(responseItem);
			} else {
				PriceDataFromExternalService dataFromExternalService = pricesFromExternalService.get(sku);
				commercestorepricing.PricingResponseItem responseItem = new commercestorepricing.PricingResponseItem(
					product.Id,
					null,
					null,
					dataFromExternalService.getListPrice(),
					dataFromExternalService.getUnitPrice()
				);

				response.addPricingResponseItem(responseItem);
			}
		}

		return response;
	 }

	 private Boolean hasNoPrices(Map<String, PriceDataFromExternalService> pricesFromExternalService, String sku){
		return pricesFromExternalService == null || pricesFromExternalService.get(sku) == null;
	 }

	class PriceDataFromExternalService {
		private Decimal listPrice;
		private Decimal unitPrice;
		
		public PriceDataFromExternalService() {
			listPrice = 0.0;
			unitPrice = 0.0;
		}
		
		public PriceDataFromExternalService(Decimal inputListPrice, Decimal inputUnitPrice) {
			listPrice = inputListPrice;
			unitPrice = inputUnitPrice;
		}
		
		public Decimal getListPrice() {
			return listPrice;
		}
		
		public Decimal getUnitPrice() {
			return unitPrice;
		}
  }
  
  public class B2BStorePricingServiceException extends Exception {}
}