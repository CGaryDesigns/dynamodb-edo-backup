/**
 * Created by cgary on 8/27/17.
 */

public class DynamoDBProvider extends DataSource.Provider {
    public override List<DataSource.AuthenticationCapability> getAuthenticationCapabilities(){
        List<DataSource.AuthenticationCapability> authCapabilityList = new List<DataSource.AuthenticationCapability>();
        authCapabilityList.add(DataSource.AuthenticationCapability.BASIC);
        return authCapabilityList;
    }
    public override List<DataSource.Capability> getCapabilities(){
        List<DataSource.Capability> capabilityList = new List<DataSource.Capability>();
        capabilityList.add(DataSource.Capability.REQUIRE_ENDPOINT);
        capabilityList.add(DataSource.Capability.REQUIRE_HTTPS);
        capabilityList.add(DataSource.Capability.ROW_QUERY);
        capabilityList.add(DataSource.Capability.ROW_CREATE);
        capabilityList.add(DataSource.Capability.ROW_DELETE);
        capabilityList.add(DataSource.Capability.ROW_UPDATE);
        capabilityList.add(DataSource.Capability.QUERY_PAGINATION_SERVER_DRIVEN);
        capabilityList.add(DataSource.Capability.QUERY_TOTAL_SIZE);

        return capabilityList;
    }
    public override DataSource.Connection getConnection(DataSource.ConnectionParams connectionParams){
        return new DynamoDBConnection(connectionParams);
    }
}