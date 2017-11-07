/**
 * This class will contain static methods to deliver information to the
 * DynamoDb Endpoint in order to read/write data.
 *
 * @author Cloud Performer <cgary@cloudperformer.com>
 * @version 1.0
 *
 **/
global class DynamoDBHelper {

    public static final String METADATA_TABLE_NAME = 'SFDCMetaData';
    public static final String AWS_SERVICE_NAME = 'dynamodb';
    public static final String TABLE_INDEX_FIELD = 'ExternalId';
    public static AmazonDynamoDBInfo__c ConfigData;

    static {
        //get the config Data
        ConfigData = AmazonDynamoDBInfo__c.getInstance('MainDynamoDBInstance');
    }

    public static void EstablishMetaData(List<String> tablesToCreate){
        Map<String,Schema.DescribeSObjectResult> resMap = new Map<String,Schema.DescribeSObjectResult>();
        Map<String,Schema.SObjectType> objMap = Schema.getGlobalDescribe();
        for(String tableToCreate:tablesToCreate){
            Schema.DescribeSObjectResult res  = objMap.get(tableToCreate).getDescribe();
            resMap.put(GenerateHashFor(res),res);
        }

        //now lets attempt the insert
        Blob payload = Blob.valueOf(GenerateMetaDataInsertString(resMap));
        Map<String,String> headerMap = new Map<String,String>();
        Url endpoint = new Url(ConfigData.EndpointUrl__c);
        HttpRequest req = AmazonUtilities.CreateSignedRequest('POST',endpoint,headerMap,payload,AWS_SERVICE_NAME,ConfigData.Region__c,ConfigData.apiKey__c,ConfigData.apiSecret__c);
        //add in the Action Type and the Content Type
        req.setHeader('X-Amz-Target','DynamoDB_20120810.BatchWriteItem');
        req.setHeader('Content-Type','application/x-amz-json-1.0');
        Http svc = new Http();
        HttpResponse res;
        try{
            res = svc.send(req);
            if(res.getStatusCode() != 200) throw new AmazonUtilities.DynamoDBException(res.getBody());
            System.debug(LoggingLevel.INFO,'\n\n Response: ' + res.getBody() + '\n\n');
        }catch(System.Exception ex){
            UniversalLogger logger = new UniversalLogger();
            logger.LogErrNow(ex);
            throw ex;
        }


    }
    public static String ObtainMetaData(){
        String stringToReturn;
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();                                                     //{
        //gen.writeStringField('ProjectionExpression','tabledata');                   //  "ProjectionExpression":"tabledata",
        gen.writeStringField('Select','ALL_ATTRIBUTES');                            //  "Select":"ALL_ATTRIBUTES",
        gen.writeStringField('TableName','SFDCMetaData');                           //  "TableName":"SFDCMetaData"
        gen.writeEndObject();                                                       //}

        System.debug(LoggingLevel.INFO,'\n\nJSON: ' + gen.getAsString() + '\n\n');

        Blob payloadData = Blob.valueOf(gen.getAsString());
        Map<String,String> headers = new Map<String,String>();
        Url endpoint = new Url(ConfigData.EndpointUrl__c);
        HttpRequest req = AmazonUtilities.CreateSignedRequest('POST',endpoint,headers,payloadData,AWS_SERVICE_NAME,ConfigData.Region__c,ConfigData.apiKey__c,ConfigData.apiSecret__c);
        req.setHeader('X-Amz-Target','DynamoDB_20120810.Scan');
        req.setHeader('Content-Type','application/x-amz-json-1.0');
        Http svc = new Http();
        HttpResponse res;
        try{
            res = svc.send(req);
            if(res.getStatusCode() != 200) throw new AmazonUtilities.DynamoDBException(res.getBody());
            stringToReturn = res.getBody();
        }catch(System.Exception ex){
            UniversalLogger logger = new UniversalLogger();
            logger.LogErrNow(ex);
            throw ex;
        }
        return stringToReturn;
    }
    public static void CreateDynamoTable(String tableName){
        CreateDynamoTable(tableName,TABLE_INDEX_FIELD);
    }
    public static void CreateDynamoTable(String tableName, String indexName){
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
            gen.writeStringField('TableName',tableName);
            gen.writeFieldName('AttributeDefinitions');
            gen.writeStartArray();
                gen.writeStartObject();
                    gen.writeStringField('AttributeName',indexName);
                    gen.writeStringField('AttributeType','S');
                gen.writeEndObject();
            gen.writeEndArray();
            gen.writeFieldName('KeySchema');
            gen.writeStartArray();
                gen.writeStartObject();
                    gen.writeStringField('AttributeName',indexName);
                    gen.writeStringField('KeyType','HASH');
                gen.writeEndObject();
            gen.writeEndArray();
            gen.writeFieldName('ProvisionedThroughput');
            gen.writeStartObject();
                gen.writeNumberField('ReadCapacityUnits',5);
                gen.writeNumberField('WriteCapacityUnits',5);
            gen.writeEndObject();
        gen.writeEndObject();

        System.debug(LoggingLevel.INFO,'\n\nJSON: ' + gen.getAsString() + '\n\n');

        //attempt to create the table
        Map<String,String> headers = new Map<String,String>();
        Blob payload = Blob.valueOf(gen.getAsString());
        Url endpoint = new Url(ConfigData.EndpointUrl__c);
        HttpRequest req = AmazonUtilities.CreateSignedRequest('POST',endpoint,headers,payload,AWS_SERVICE_NAME,ConfigData.Region__c,ConfigData.apiKey__c,ConfigData.apiSecret__c);
        req.setHeader('X-Amz-Target','DynamoDB_20120810.CreateTable');
        req.setHeader('Content-Type','application/x-amz-json-1.0');
        Http svc = new Http();
        HttpResponse res;
        try {
            res = svc.send(req);
            if(res.getStatusCode() != 200) throw new AmazonUtilities.DynamoDBException(res.getBody());
        }catch(System.Exception ex){
            UniversalLogger logger = new UniversalLogger();
            logger.LogErrNow(ex);
            throw ex;
        }

    }
    /**
     * This method can be used to write a single record in Salesforce to DynamoDB
     *
     * @param sObject record                        -the record to send to DynamoDB
     */
    public static void PutRecord(SObject record, String externalTableName){
        System.debug(LoggingLevel.INFO,'\n\n*****\nJSON represenation:\n' + JSON.serialize(record));

        //first we need to create a map of fieldNames to AmazonDataTypes
        Map<String,String> fieldNameToAmazonDataType = new Map<String,String>();
        Schema.DescribeSObjectResult recTypeDescribe = record.getSObjectType().getDescribe();
        Map<String,SObjectField> fieldMap = recTypeDescribe.fields.getMap();
        Map<String, Object> populatedFieldMap = record.getPopulatedFieldsAsMap();
        for(String fieldName :populatedFieldMap.keySet()){
            fieldNameToAmazonDataType.put(fieldName, DetermineAmazonFieldType(fieldMap.get(fieldName)) );
        }
        //now we build the JSONString
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
            gen.writeStringField('TableName',externalTableName);
            gen.writeFieldName('Item');
            gen.writeStartObject();
            for(String fieldKey :populatedFieldMap.keySet()){
                gen.writeFieldName(fieldKey);
                gen.writeStartObject();
                    String dynamoDataType = fieldNameToAmazonDataType.get(fieldKey);
                    gen.writeStringField(dynamoDataType,String.valueOf(record.get(fieldKey)));
                gen.writeEndObject();
            }
                gen.writeFieldName(TABLE_INDEX_FIELD);
                gen.writeStartObject();
                    gen.writeStringField('S',String.valueOf(record.get('Id')));
                gen.writeEndObject();
            gen.writeEndObject();
        gen.writeEndObject();

        //now lets attempt the insert
        Map<String,String> headerMap = new Map<String,String>();
        Blob payload = Blob.valueOf(gen.getAsString());
        Url endpoint = new Url(ConfigData.EndpointUrl__c);
        HttpRequest req = AmazonUtilities.CreateSignedRequest('POST',endpoint,headerMap,payload,AWS_SERVICE_NAME,ConfigData.Region__c,ConfigData.apiKey__c,ConfigData.apiSecret__c);
        req.setHeader('X-Amz-Target','DynamoDB_20120810.PutItem');
        req.setHeader('Content-Type','application/x-amz-json-1.0');
        Http svc = new Http();
        HttpResponse res;
        try{
            res = svc.send(req);
            if(res.getStatusCode() != 200) throw new AmazonUtilities.DynamoDBException(res.getBody());
            System.debug(LoggingLevel.INFO,'\n\n' + res.getBody() + '\n\n');
        }catch(System.Exception ex){
            UniversalLogger logger = new UniversalLogger();
            logger.LogErrNow(ex);
            throw ex;
        }
    }
    public static void PutRecords(List<SObject> recordList, String externalTableName){
        //first we need to create a map of fieldNames to AmazonDataTypes
        Map<String,String> fieldNameToAmazonDataType = new Map<String,String>();
        Schema.DescribeSObjectResult res = recordList[0].getSObjectType().getDescribe();
        Map<String,SObjectField> fieldMap = res.fields.getMap();
        for(String fieldName :fieldMap.keySet()){
            fieldNameToAmazonDataType.put(fieldName, DetermineAmazonFieldType(fieldMap.get(fieldName)) );
        }
        

        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
            gen.writeFieldName('RequestItems');
            gen.writeStartObject();
                gen.writeFieldName(externalTableName);
                gen.writeStartArray();
                for(SObject rec:recordList){
                    Map<String,Object> populatedFieldMap = rec.getPopulatedFieldsAsMap();
                    Set<String> lowerCasePopulatedFieldMap = new Set<String>();
                    for(String field:populatedFieldMap.keySet()){
                        lowerCasePopulatedFieldMap.add(field.toLowerCase());
                    }
                    gen.writeStartObject();
                        gen.writeFieldName('PutRequest');
                        gen.writeStartObject();
                            gen.writeFieldName('Item');
                            gen.writeStartObject();
                            for(String fieldKey:fieldMap.keySet()){

                                if(lowerCasePopulatedFieldMap.contains(fieldKey)){
                                    gen.writeFieldName(fieldKey);
                                    gen.writeStartObject();
                                        gen.writeStringField(fieldNameToAmazonDataType.get(fieldKey),(!String.isBlank(String.valueOf(rec.get(fieldKey))) ? String.valueOf(rec.get(fieldKey)) :''));
                                    gen.writeEndObject();
                                }
                            }
                                gen.writeFieldName(TABLE_INDEX_FIELD);
                                gen.writeStartObject();
                                gen.writeStringField('S',String.valueOf(rec.get('Id')));
                                gen.writeEndObject();
                            gen.writeEndObject();
                        gen.writeEndObject();
                    gen.writeEndObject();


                }
                gen.writeEndArray();
            gen.writeEndObject();
        gen.writeEndObject();

        System.debug(LoggingLevel.INFO,'\n\n Payload: ' + gen.getAsString() + '\n\n');

        //lets make the request
        Map<String,String> headerMap = new Map<String,String>();
        Blob payload = Blob.valueOf(gen.getAsString());
        Url endpoint = new Url(ConfigData.EndpointUrl__c);
        HttpRequest req = AmazonUtilities.CreateSignedRequest('POST',endpoint,headerMap,payload,AWS_SERVICE_NAME,ConfigData.Region__c,ConfigData.apiKey__c,ConfigData.apiSecret__c);
        req.setHeader('X-Amz-Target','DynamoDB_20120810.BatchWriteItem');
        req.setHeader('Content-Type','application/x-amz-json-1.0');
        Http svc = new Http();
        HttpResponse httpRes;
        try{
            httpRes = svc.send(req);
            if(httpRes.getStatusCode() != 200) throw new AmazonUtilities.DynamoDBException(httpRes.getBody());
            System.debug(LoggingLevel.INFO,'\n\n Response: ' + httpRes.getBody() + '\n\n');
        }catch(System.Exception ex){
            UniversalLogger logger = new UniversalLogger();
            logger.LogErrNow(ex);
            throw ex;
        }

    }
    public static String GetRecords(String tableName, List<String> fieldList, List<String> projectionExpressions, String startKey){
        //create the request JSON Object
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();                                                         //{
            gen.writeStringField('TableName', tableName);                               //  "TableName":<tableName>,
            gen.writeFieldName('ExclusiveStartKey');                                    //  "ExclusiveStartKey":
            gen.writeStartObject();                                                     //  {
                gen.writeFieldName('ExternalId');                                       //      "ExternalId":
                gen.writeStartObject();                                                 //      {
                    gen.writeStringField('S', startKey);                                 //          "S":<startKey>    
                gen.writeEndObject();                                                   //      }
            gen.writeEndObject();                                                       //  },
            gen.writeStringField('ProjectionExpression', String.join(fieldList,','));   //  "ProjectionExpression":<fieldList parts>,
            gen.writeStringField('ReturnConsumedCapacity','INDEXES');                   //  "ReturnConsumedCapacity":"INDEXES",
            gen.writeStringField('Select','ALL_PROJECTED_ATTRIBUTES');                  //  "Select":"ALL_PROJECTED_ATTRIBUTES"
        gen.writeEndObject();                                                           //}
        //now lets make the request:
        Map<String,String> headerMap = new Map<String,String>();
        Blob payload = Blob.valueOf(gen.getAsString());
        Url endpoint = new Url(ConfigData.EndpointUrl__c);
        HttpRequest req = AmazonUtilities.CreateSignedRequest('GET', endpoint, headerMap, payload, AWS_SERVICE_NAME, ConfigData.Region__c,ConfigData.apiKey__c,ConfigData.apiSecret__c);
        req.setHeader('X-Amz-Target','DynamoDB20120810.Scan');
        req.setHeader('Content-Type','application/x-amz-json-1.0');
        Http svc = new Http();
        HttpResponse res;
        String resultString;
        try{
            res = svc.send(req);
            if(res.getStatusCode() != 200) throw new AmazonUtilities.DynamoDBException(req.getBody());
            resultString = res.getBody();
        }catch(System.Exception ex){
            UniversalLogger logger = new UniversalLogger();
            logger.LogErrNow(ex);
            throw ex;
        }
        return resultString;
    }   
    /**
     * This method is designed to generate the JSON needed to insert the metadata about the tables being archived
     * into the main MetaData table on DynamoDB.
     *
     * @param Map<String,Schema.DescribeSObjectResult>              - a map with a hexEncoded hash of the table as the key.
     * @return String                                               - the payload String
     **/
    private static String GenerateMetaDataInsertString(Map<String,Schema.DescribeSObjectResult> resMap){
        JSONGenerator jsonObj = JSON.createGenerator(true);
        jsonObj.writeStartObject();
        jsonObj.writeFieldName('RequestItems');
        jsonObj.writeStartObject();

        jsonObj.writeFieldName(METADATA_TABLE_NAME);
        jsonObj.writeStartArray();
        for(String resItem:resMap.keySet()){
            //begin the object
            jsonObj.writeStartObject();

            //write start PutRequest
            jsonObj.writeFieldName('PutRequest');
            jsonObj.writeStartObject();
            jsonObj.writeFieldName('Item');
            //start writing the item record
            jsonObj.writeStartObject();

            jsonObj.writeFieldName('objecthash');
            jsonObj.writeStartObject();
            jsonObj.writeStringField('S',resItem);
            jsonObj.writeEndObject();

            jsonObj.writeFieldName('tabledata');
            jsonObj.writeStartObject();
            jsonObj.writeStringField('S',JSON.serialize(resMap.get(resItem)));
            jsonObj.writeEndObject();
            //end writing the item record
            jsonObj.writeEndObject();
            //end writing PutRequest
            jsonObj.writeEndObject();

            //end the object
            jsonObj.writeEndObject();
        }
        jsonObj.writeEndArray();

        jsonObj.writeEndObject();
        jsonObj.writeStringField('ReturnConsumedCapacity','TOTAL');
        jsonObj.writeEndObject();

        return jsonObj.getAsString();
    }
    /**
     * There are only 3 Amazon Data Types - B - Binary, N - Number, and S - String. We need to convert what the
     * Salesforce Data type is to the Amazon DynamoDB Data Type.
    **/
    private static String DetermineAmazonFieldType(Schema.SObjectField fieldInfo){
        Schema.DisplayType display = fieldInfo.getDescribe().type;
        String returnType = 'S';
        if(display == Schema.DisplayType.CURRENCY ||
           display == Schema.DisplayType.DOUBLE ||
           display == Schema.DisplayType.INTEGER) {
            returnType = 'N';
        }
        return returnType;
    }
    /**
     * General method to take any object and generate a hash for it.
     *
     * @param Object record                                 -really any object that can be serialized. There are
     *                                                       a few objects on the Salesforce platform that can't be
     *                                                       serialized.
     * @param String                                        -a hexadecimal representation of the md5hash of the data.
     **/
    private static String GenerateHashFor(Object record){
        Blob hash = Crypto.generateDigest('MD5',Blob.valueOf(JSON.serialize(record)));
        return EncodingUtil.convertToHex(hash);
    }
}