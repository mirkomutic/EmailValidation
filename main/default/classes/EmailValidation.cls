public class EmailValidation {
    //The 'processEmailValidation' method will check if all relevant templates for a stage were sent
    //Object and Picklist configuration is in Custom Metadata Type 'ObjectStatusMappings__mdt'
    //Stage/Email-Template mapping is in Custom Metadata Type 'EmailValidationParameter__mdt'

    //1. Query all related email messages and create a map of the TemplateDeveloperName that was used and the EmailMessage record
    //2. Compare the required EmailTemplates for each status by looking for the template developer name of the template in map

    public static void processEmailValidation(Map<Id, SObject> newMapRecords, Map<Id, SObject> oldMapRecords, String statusField){
        //Query related Email Message records for projects in Trigger.new
        List<EmailMessage> emailList = [SELECT Id, EmailTemplate.DeveloperName, RelatedToId FROM EmailMessage WHERE RelatedToId IN :newMapRecords.keySet() AND EmailTemplateId != NULL];

        //create map of EmailTemplate DeveloperNames and EmailMessage records
        Map<String,EmailMessage> emailMapByTemplateDeveloperName = new Map<String,EmailMessage>();
        for(EmailMessage email : emailList){
            emailMapByTemplateDeveloperName.put(email.EmailTemplate.DeveloperName,email);
        }

        //initialize variables for if-conditions
        Boolean emailSent = false;
        Boolean statusChanged = false;
        Boolean hasRelevantTemplates = false;

        //loop records and verify that the relevant emails were sent, based on aforementioned custom metadata
        //a single status can have more than one required email template. We store them comma separated in custom mdt and split here.
        for(SObject record : newMapRecords.values()){
            //get sobject type and status field name from custom mdt
            String sobjectType = record.getSObjectType().getDescribe().getName();
                
                //create variable for old and new picklist status value
                String newStatus = (String) record.get(statusField);
                String oldStatus = (String) oldMapRecords.get(record.Id).get(statusField);
                
                // Compare the order of the statuses to determine if status has progressed                
                Decimal oldStatusOrder = EmailValidationParameter__mdt.getInstance(oldStatus) != null ? EmailValidationParameter__mdt.getInstance(oldStatus).Order__c : 0;
                Decimal newStatusOrder = EmailValidationParameter__mdt.getInstance(newStatus) != null ? EmailValidationParameter__mdt.getInstance(newStatus).Order__c : 0;
                statusChanged = oldStatusOrder != 0 && (newStatusOrder > oldStatusOrder);
                
                //check if the status has required templates
                hasRelevantTemplates = EmailValidationParameter__mdt.getInstance(oldStatus) != null ? EmailValidationParameter__mdt.getInstance(oldStatus).RelevantTemplates__c != '' : false;
                
                
                //execute logic only if status has progressed and the status has required templates
                if(statusChanged && hasRelevantTemplates){
                    List<String> relevantTemplates = EmailValidationParameter__mdt.getInstance(oldStatus).RelevantTemplates__c.split(',');
                    //loop one or more required templates from mdt and check if it was used for the project by referencing the maps above
                    for(String template : relevantTemplates){
                        Boolean templateWasNotUsed = emailMapByTemplateDeveloperName.get(template) != null;
                        emailSent = !templateWasNotUsed ? false : emailMapByTemplateDeveloperName.get(template).RelatedToId == record.Id;
                        if(!emailSent){
                            break;
                        }
                    }
                }
                //add error if the status has changed and one or more of the required templates are missing
                if(statusChanged && !emailSent){
                    record.addError(EmailValidationParameter__mdt.getInstance(oldStatus).ErrorMessage__c);
                }            
        }
    }
}
