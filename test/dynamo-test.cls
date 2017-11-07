//create the Account Table
//DynamoDBHelper.CreateDynamoTable('Case','ExternalId');
List<Contact> contactList = [SELECT Id, FirstName, LastName, Email FROM Contact LIMIT 20];
DynamoDBHelper.PutRecords(contactList,'Contact');
