global class DynamoDBMockCallout implements HttpCalloutMock {
    public DynamoDBMockCallout() {

    }

    public HttpResponse respond(HttpRequest req){
        HttpResponse res;

        //first we need to determine what type of Request this is
        String requestType = req.getHeader('X-Amz-Target');
        List<String> requestCommandList = requestType.split('.');
        if(requestCommandList[1] == 'BatchWriteItem'){
            //we know that we are writing some items, they may be entries into the SFDCMetaData
            //table or into another seperate table.
        } else if(requestCommandList[1] == 'Scan'){
            //we know that we are reading some items, they may be entries into the SFDCMetaData
            //table or into another separate table

<<<<<<< HEAD
        } else if(requestCommandList[1] == 'CreateTable'){
            //put together a date Strign
            String currentDateString = String.valueOf(Date.today().year());
            currentDateString += '-' + String.valueOf(Date.today().month());
            currentDateString += '-' + String.valueOf(Date.today().day());
=======
        } else if(reqeustCommandList[1] == 'CreateTable'){
>>>>>>> parent of d94e398... Updates to Mock Callout implementation for DynamoDB Testing
            res.setStatus('OK');
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/x-amz-json-1.0');
            res.setHeader('Date',Date.today().format('YYYY-MM-DD'));
            JSONGenerator gen = JSON.createGenerator(true);
            gen.writeStartObject();
                gen.writeFieldName('TableDescription');
                gen.writeStartObject();
                    gen.writeStringField('TableArn', 'arn:aws:dynamodb:us-west-2:123456789012:table/Thread');
                    gen.writeFieldName('AttributeDefinitions');
                    gen.writeStartArray();
                        gen.writeStartObject();
                            gen.writeStringField('AttributeName','ExternalId');
                            gen.writeStringField('AttributeType', 'S');
                        gen.writeEndObject();
                    gen.writeEndArray();
                    gen.writeNumberField('CreationDateTime', 1.36372808007);
                    gen.writeNumberField('ItemCount',0);
                    gen.writeFieldName('KeySchema');
                    gen.writeStartArray();
                        gen.writeStartObject();
                            gen.writeStringField('AttributeName', 'ExternalId');
                            gen.writeStringField('KeyType','HASH');
                        gen.writeEndObject();
                    gen.writeEndArray();
                    gen.writeFieldName('ProvisionedThroughput');
                    gen.writeStartObject();
                        gen.writeNumberField('NumberOfDecreasesToday', 0);
                        gen.writeNumberField('ReadCapacityUnits',5);
                        gen.writeNumberField('WriteCapacityUnits',5);
                    gen.writeEndObject();
                    gen.writeStringField('TableName','Thread');
                    gen.writeNumberField('TableSizeBytes',0);
                    gen.writeStringField('TableStatus','CREATING');
                gen.writeEndObject();
            gen.writeEndObject();
            res.setBody(gen.getAsString());
        }

        return res;
    }
}
