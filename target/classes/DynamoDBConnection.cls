/**
 * Originally, this Connection was to be a straight line External Data Objects
 * Connection between DynamoDB and Salesforce. However, becuase DynamoDB is a schemaless
 * data structure, there aren't really any fields to pull back from the DynamoDB Describe Calls(other than primary keys).
 * So this now has turned into a Salesforce Data Archival System. By creating tables on
 * DynamoDB that mirror the SObject names in a Salesforce instance, we will create a false table
 * structure on DynamoDB that mirrors the object structure for archival purposes.
 *
 * @author Cloud Performer <cgary@cloudperformer.com>
 * @version 1.0
 */

global class DynamoDBConnection extends DataSource.Connection {
    //logging purposes
    private UniversalLogger logger { get; set; }
    //this is a hardcoded String that instructs the AWS API to use the Dynamo DB
    private static final String AWS_SERVICE_NAME = 'dynamodb';
    //This is a variable that should be moved to an Custom MetaData API to instruct
    //which region is being used for the AWS API
    private static final String AWS_SERVICE_REGION = 'us-east-1';
    //parameters that have been passed in to connect the AWS DynamoDB Service
    public DataSource.ConnectionParams params { get; set; }
    //a list of Salesforce SObjects
    private Set<String> sObjectList { get; set; }
    /**
     * Constructor.
     **/
    public DynamoDBConnection(DataSource.ConnectionParams connectionParams){
        this.params = connectionParams;
        this.logger = new UniversalLogger();
        this.sObjectList = Schema.getGlobalDescribe().keySet();
    }
    /**
     * This method is responsible for getting the table architecture for the DynamoDB Connection.
     * Because DynamoDB is actually a stateless Database, we rely on a MetaData Table, much the same
     * as standard Databases, in order to tell us what tables and fields are created.
     *
     * @return List<DataSource.Table> list of Data Source Tables.
     **/
    global override List<DataSource.Table> sync() {
        Map<String,SObjectType> globalMap = Schema.getGlobalDescribe();
        String resultSet = DynamoDBHelper.ObtainMetaData();
        this.logger.LogNow(resultSet);
        //lets parse this return
        List<Schema.DescribeSObjectResult> resultList = new List<Schema.DescribeSObjectResult>();
        Map<String,Object> returnObj = (Map<String,Object>)JSON.deserializeUntyped(resultSet);
        List<Object> itemList = (List<Object>)returnObj.get('Items');
        for(Object item:itemList){
            Map<String,Object> itemMap = (Map<String,Object>)item;
            Map<String,Object> itemSchema = (Map<String,Object>)itemMap.get('tabledata');
            String tableItemDefinition = String.valueOf(itemSchema.get('S'));
            Map<String,Object> objItem = (Map<String,Object>)JSON.deserializeUntyped(tableItemDefinition);
            String tableName = String.valueOf(objItem.get('name'));
            Schema.SObjectType type = globalMap.get(tableName);
            resultList.add(type.getDescribe());
        }
        this.logger.LogNow('Deserialization Complete.');
        //system.debug(LoggingLevel.INFO,'\n\n Have a List of Table structures now.' + '\n\n');
        List<DataSource.Table> returnTableList = new List<DataSource.Table>();
        for(Schema.DescribeSObjectResult tableDescribe:resultList){
            List<DataSource.Column> columns = new List<DataSource.Column>();
            Map<String,SObjectField> fieldMap = tableDescribe.fields.getMap();
            columns.add(DataSource.Column.text('ExternalId','External ID',255));
            columns.add(DataSource.Column.url('DisplayUrl'));
            for(String fieldName:fieldMap.keySet()){
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                Schema.DisplayType fieldType = dfr.getType();
                if(fieldType == Schema.DisplayType.INTEGER){
                    columns.add(DataSource.Column.integer(dfr.getName(),dfr.getLength()));
                } else if(fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.CURRENCY){
                    columns.add(DataSource.Column.number(dfr.getName(),dfr.getLength(),dfr.getPrecision()));
                } else if(fieldType == Schema.DisplayType.TEXTAREA){
                    columns.add(DataSource.Column.textarea(dfr.getName()));
                } else {
                    columns.add(DataSource.Column.text(dfr.getName(),dfr.getLabel(),255));
                }
            }
            returnTableList.add(DataSource.Table.get(tableDescribe.getName(),tableDescribe.getLabel(),tableDescribe.getLabelPlural(),'Backup Table for' + tableDescribe.getLabel(),'ExternalId',columns));
        }
        return returnTableList;
    }
    /**
     * This method is responsible for querying data from DynamoDB.  In reality, unless the
     * actual PriaryKeyfield is used, it is going to be a table scan , not a query on DynamoDB.
     *
     * @param DataSource.
     **/
    global override DataSource.TableResult query(DataSource.QueryContext context){
        return null;
    }
    global override List<DataSource.UpsertResult> upsertRows(DataSource.UpsertContext context){
        return null;
    }
    global override List<DataSource.DeleteResult> deleteRows(DataSource.DeleteContext context){
        return null;
    }
}