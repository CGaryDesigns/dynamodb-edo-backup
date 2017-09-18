/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class AmazonUtilitiesTest {

    @isTest
    static void canonicalMethodFor(){
        Test.startTest();

        String result = AmazonUtilities.canonicalMethodFor('post');
        System.assertEquals('POST', result);

        Test.stopTest();
    }

    @isTest
    static void canonicalUriFor(){
        Test.startTest();

        String result = AmazonUtilities.canonicalUriFor('http://www.google.com/fun/test/again?id=foo&value=bar');
        System.assertEquals('/fun/test/again', result);

        Test.stopTest();
    }

    @isTest
    static void canonicalQueryStringFor(){
        Test.startTest();

        Map<String,String> headerMap = new Map<String,String>();
        headerMap.put('foo1','bar1');
        headerMap.put('foo2','bar2');
        headerMap.put('amazonTest','again');
        String result = AmazonUtilities.canonicalQueryStringFor(headerMap);

        Test.stopTest();
    }

    @isTest
    static void canonicalHeadersFor(){
        Test.startTest();

        Map<String,String> headerMap = new Map<String,String>();
        headerMap.put('foo1','bar1');
        headerMap.put('foo2','bar2');
        headerMap.put('amazonTest','again');
        String result = AmazonUtilities.canonicalQueryStringFor(headerMap);

        Test.stopTest();
    }

    @isTest
    static void signedHeadersFor(){
        Test.startTest();

        Map<String,String> headerMap = new Map<String,String>();
        headerMap.put('foo1','bar1');
        headerMap.put('foo2','bar2');
        headerMap.put('amazonTest','again');
        String result = AmazonUtilities.signedHeadersFor(headerMap);

        Test.stopTest();
    }

    @isTest
    static void hexEncodedHashFor(){
        Test.startTest();

        Blob payloadBlob = Blob.valueOf('This is a test of the emergency broadcase system');
        String hexEncodedResult = AmazonUtilities.hexEncodedHashFor(payloadBlob);

        Test.stopTest();
    }

    @isTest
    static void rfc3986For(){
        Test.startTest();

        String testString = 'This is a test';
        String result = AmazonUtilities.rfc3986For(testString, true);

        Test.stopTest();
    }

    @isTest
    static void CreateSignedRequest(){
        Test.startTest();
        
        Url testUrl = new Url('https://us-east-1.amazon.com/dynamodb/test');
        Map<String,String> headerMap = new Map<String,String>();
        Blob payloadData = Blob.valueOf('This is a test');
        headerMap.put('foo1','bar1');
        headerMap.put('foo2','bar2');
        HttpRequest req = AmazonUtilities.CreateSignedRequest('POST', testUrl, headerMap, payloadData, 'dynamodb', 'us-east-1', 'testkey', 'testapiname');

        Test.stopTest();
    }
}