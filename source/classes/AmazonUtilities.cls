/**
 * Created by cgary on 8/27/17.
 */

public class AmazonUtilities {
    public static HttpRequest CreateSignedRequest(String method, Url endpoint, Map<String,String> headers, Blob payload, String service, String region, String apiKey, String apiSecret) {
        //defaults
        if(headers == null) headers = new Map<String,String>();
        if(payload == null) payload = Blob.valueOf('');
        Boolean presign = false;
        Datetime thisMoment = Datetime.now();

        //assemble
        String termination = 'aws4_request';
        String iso8601date = thisMoment.formatGmt('YYYYMMdd');
        String iso8601time = thisMoment.formatGmt('YYYYMMdd\'T\'HHmmss\'Z\'');
        String credentialScope = iso8601date + '/' + region + '/' + service + '/' + termination;

        //prepare headers
        headers.put('Host',endpoint.getHost());
        String signedHeaders = signedHeadersFor(headers);

        //handle spaces and special characters in paths
        String spec = '';
        spec += endpoint.getProtocol() + '://';
        spec += endpoint.getHost();
        spec += rfc3986For(endpoint.getPath(), false);
        if(endpoint.getQuery() != null) spec += '?' + endpoint.getQuery();

        //prepare paramters
        PageReference pr = new Pagereference(spec);
        Map<String,String> parameters = pr.getParameters();
        parameters.put('X-Amz-Algorithm','AWS4-HMAC-SHA256');
        parameters.put('X-Amz-Credential', apiKey + '/' + credentialScope);
        parameters.put('X-Amz-Date',iso8601time);
        parameters.put('X-Amz-Expires','86400');
        parameters.put('X-Amz-SignedHeaders',signedHeaders);

        //Task 1: Create a Canonical Request for Signature Version 4.
        String canonicalRequest = canonicalMethodFor(method)
                + '\n' + canonicalUriFor(endpoint.toExternalForm())
                + '\n' + canonicalQueryStringFor(parameters)
                + '\n' + canonicalHeadersFor(headers)
                + '\n' + signedHeadersFor(headers)
                + '\n' + (presign ? 'UNSIGNED-PAYLOAD' : hexEncodedHashFor(payload))
        ;
        //System.debug(LoggingLevel.INFO,'\n\nCanonical Request:\n' + canonicalRequest + '\n\n');

        //Task 2: Create a Canonical Requst for Signature Version 4.
        String algorithm = 'AWS4-HMAC-SHA256';
        String canonicalRequestHash = hexEncodedHashFor(Blob.valueOf(canonicalRequest));
        String stringToSign  = algorithm + '\n' + iso8601time + '\n' + credentialScope + '\n' + canonicalRequestHash;
        String headerStringToSign  = algorithm + ' Credential=' + credentialScope +  ', SignedHeaders=' + signedHeadersFor(headers) + ', Signature=' + canonicalRequestHash;
        //System.debug(Logginglevel.INFO,'\n\nString To Sign:\n' + stringToSign + '\n\n');
        //System.debug(Logginglevel.INFO,'\n\n Header String To Sign:\n' + headerStringToSign + '\n\n');

        //Task 3: Calculate the AWS Signature Version 4
        Blob keyDate = Crypto.generateMac('hmacSHA256', Blob.valueOf(iso8601date), Blob.valueOf('AWS4' + apiSecret));
        Blob keyRegion = Crypto.generateMac('hmacSHA256', Blob.valueOf(region), keyDate);
        Blob keyService = Crypto.generateMac('hmacSHA256', Blob.valueOf(service), keyRegion);
        Blob keySigning = Crypto.generateMac('hmacSHA256', Blob.valueOf('aws4_request'), keyService);

        Blob blobToSign = Blob.valueOf(stringToSign);
        Blob hmac = Crypto.generateMac('hmacSHA256', blobToSign, keySigning);

        //Task 4: Adding the signing information to the Request
        if(!presign) headers.put('X-Amz-Content-Sha256',hexEncodedHashFor(payload));
        String signature  = EncodingUtil.convertToHex(hmac);
        //System.debug(LoggingLevel.INFO,'\n\nSignature:\n' + signature + '\n\n' );
        parameters.put('X-Amz-Signature',signature);
        //parameters.put('Authorization',headerStringToSign);

        //prepare request
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setEndpoint(pr.getUrl());
        if(payload != Blob.valueOf('')) request.setBodyAsBlob(payload);
        //dont need this
        //for(String header : headers.keySet()) request.setHeader(header, headers.get(header));

        return request;
    }

    private static String canonicalMethodFor(String method) {
        return method.toUpperCase();
    }

    private static String canonicalUriFor(String endpoint) {
        Url uri = new Url(endpoint);
        return rfc3986For(uri.getPath(), false);
    }

    private static String canonicalQueryStringFor(Map<String,String> parameters) {

        //sort keys by ascii code
        List<String> sortedKeys = new List<String>(parameters.keySet());
        sortedKeys.sort();

        //prepare values
        List<String> canonicalParameters = new List<String>();
        for (String sortedKey : sortedKeys) canonicalParameters.add(
        sortedKey +
        '=' +
        rfc3986For(parameters.get(sortedKey), true)
        );

        return String.join(canonicalParameters, '&');
    }

    private static String canonicalHeadersFor(Map<String,String> key2value) {

        //lowercase header keys
        Map<String,String> lower2value = new Map<String,String>();
        for (String key : key2value.keySet()) lower2value.put(key.toLowerCase(), key2value.get(key).trim().replaceAll('\\s+', ' '));

        //sort canonical keys by ascii code
        List<String> sortedKeys = new List<String>(lower2value.keySet());
        sortedKeys.sort();

        //prepare values
        List<String> canonicalHeaders = new List<String>();
        for (String sortedKey : sortedKeys) canonicalHeaders.add(sortedKey + ':' + lower2value.get(sortedKey) + '\n');

        return String.join(canonicalHeaders, '');
    }

    private static String signedHeadersFor(Map<String,String> headers) {

        //lowercase header keys
        List<String> keys = new List<String>(headers.keySet());
        for (Integer i = 0; i < keys.size(); i++) keys.set(i, keys[i].toLowerCase());

        //sort ascii
        keys.sort();

        //prepare values
        List<String> signedHeaders = new List<String>();
        for (String key : keys) signedHeaders.add(key);

        return String.join(signedHeaders, ';');
    }

    private static String hexEncodedHashFor(Blob data) {
        Blob hash = Crypto.generateDigest('SHA256', data);
        return EncodingUtil.convertToHex(hash);
    }

    private static String rfc3986For(String characters, Boolean encodeSlash) {
        String result = '';
        for (Integer i = 0; i < characters.length(); i++) {
            String character = characters.substring(i, i + 1);

            if (
            (character >= 'A' && character <= 'Z') ||
            (character >= 'a' && character <= 'z') ||
            (character >= '0' && character <= '9') ||
            character == '_' ||
            character == '-' ||
            character == '~' ||
            character == '.'
            ) {
                result += character;
            } else if (character == '/') {
                result += encodeSlash ? '%2F' : character;
            } else {
                result += '%' + EncodingUtil.convertToHex(Blob.valueOf(character)).toUpperCase();
            }
        }
        return result;
    }
    
    public class DynamoDBException extends Exception {}
    
}