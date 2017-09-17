/**
 * The purpose of the Class is to serve as a Universal Logging
 * System to use in order to report, analyze errors, Issue debug
 * statements in a central location that is standardized across
 * any Salesforce instance where this is implemented. The initial
 * implementation will use LaaS (Logging As A Service) vendor 'Loggly'.
 * Eventually, the LaaS system should be pluggable.
 *
 * @author Cloud Performer <cgary@cloudperformer.com>
 * @version 1.0
 */

global class UniversalLogger {
    public interface Logger{
        void LogError(String message, Integer lineNumber, String stackTrace);
        void LogInfo(String message);
    }
    public class LogMessage{
        public String message { get; set;}
        public Integer lineNumber { get; set;}
        public String stackTrace { get; set; }
        public String severity { get; set; }
        public LogMessage(){}
        public LogMessage(String msg, Integer ln, String st, String svty){
            this.message = msg;
            this.lineNumber = ln;
            this.stackTrace = st;
            this.severity = svty;
        }
        public LogMessage(String msg){
            this.message = msg;
            this.lineNumber = 0;
            this.severity = 'INFO';
            this.stackTrace = 'empty';
        }
        public LogMessage(System.Exception ex){
            this.message = ex.getMessage();
            this.lineNumber = ex.getLineNumber();
            this.stackTrace = ex.getStackTraceString();
            this.severity = 'ERROR';
        }
    }
    public class Loggly implements UniversalLogger.Logger {
        public String endpoint { get; set; }
        public String accountId { get; set; }
        public String logTags { get; set; }
        public Http svc { get; set; }
        /**
         * constructor that will pull configuration based on the name
         * of the conguration record that needs to be pulled in.
         *
         * @param String metadataType - the name of the MetaData Type record.
         */
        public Loggly(String metadataType){
            LoggingSetting__mdt configSetting;
            try {
                configSetting = [SELECT Id, MasterLabel, AccountId__c, EndpointPattern__c, LogTags__c FROM LoggingSetting__mdt WHERE MasterLabel = :metadataType];
            } catch(System.Exception ex){
                throw new UniversalLogger.UniversalLoggerException('the Configuration for The universal Logger has not been setup properly.');
            }
            this.accountId = configSetting.AccountId__c;
            this.logTags = configSetting.LogTags__c;
            String urlPattern = configSetting.EndpointPattern__c;
            this.endpoint = urlPattern.replaceAll('\\{accountId\\}',this.accountId);
            //initialize Http Service
            this.svc = new Http();
        }
        /**
         * default constructor.
         */
        public Loggly(){
            this('Loggly');
        }
        /**
         * Implementation of the Logger.LogError Interface
         */
        public void LogError(String message, Integer lineNumber, String stackTrace){
            UniversalLogger.LogMessage msg = new UniversalLogger.LogMessage(message, lineNumber, stackTrace, 'ERROR');
            this.SendLog(msg);

        }
        public void LogInfo(String message){
            UniversalLogger.LogMessage msg = new UniversalLogger.LogMessage(message);
            this.SendLog(msg);
        }
        /**
         * actual method to send log
         *
         * @param UniversalLogger.LogMessage msg    - the message to log at Loggly
         */
        private void SendLog(UniversalLogger.LogMessage msg){
            String loggingTags = 'Salesforce,' + UserInfo.getOrganizationId();
            if(!String.isBlank(this.logTags)){
                loggingTags += ',' + this.logTags;
            }
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(this.endpoint);
            req.setTimeout(60000);
            req.setBody(JSON.serialize(msg));
            req.setHeader('Content-Type','application/json');
            req.setHeader('X-LOGGLY-TAG',loggingTags);
            HttpResponse res;
            try{
                res = this.svc.send(req);
            } catch(System.Exception ex){
                throw new UniversalLogger.UniversalLoggerException(ex.getMessage());
            }
        }

    }


    //universal Logger Information
    private static UniversalLogger.Logger staticLogger;
    private UniversalLogger.Logger loggerInstance { get; set; }
    /**
     * Static constructor
     */
    static{
        staticLogger = new Loggly();
    }
    /**
     * non static Constructor
     */
    public UniversalLogger(){
        this.loggerInstance = new Loggly();
    }

    public void LogNow(String message){
        this.loggerInstance.LogInfo(message);
    }
    public void LogErrNow(String message, Integer lineNumber, String stackTrace){
        this.loggerInstance.LogError(message,lineNumber,stackTrace);
    }
    public void LogErrNow(System.Exception ex){
        this.loggerInstance.LogError(ex.getMessage(),ex.getLineNumber(),ex.getStackTraceString());
    }

    @future(callout=true)
    public static void log(String message){
        UniversalLogger.staticLogger.LogInfo(message);
    }
    @future(callout=true)
    public static void logErr(String message, Integer lineNumber, String stackTrace){
        UniversalLogger.staticLogger.LogError(message, lineNumber, stackTrace);
    }

    public class UniversalLoggerException extends Exception{}
}