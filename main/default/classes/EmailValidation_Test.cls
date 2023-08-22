@isTest
public class EmailValidation_Test {

    @TestSetup
    static void setupData(){
        Account acc = new Account(
                Name = 'TestAcc' + System.now()
        );
        insert acc;

        Opportunity oppOld = new Opportunity(
                Name = 'TestOpp' + System.now(),
                AccountId = acc.Id,
                CloseDate = System.today(),
                StageName = 'Prospecting'
        );

        Opportunity oppNew = new Opportunity(
                Name = 'TestOpp' + System.now(),
                AccountId = acc.Id,
                CloseDate = System.today(),
                StageName = 'Pledged'
        );

        insert new List<SObject>{oppOld, oppNew};

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser){
            EmailTemplate testTemplate = new EmailTemplate(
                    Name = 'TestTemplateForProjectProcess',
                    FolderId = thisUser.Id,
                    TemplateType ='custom',
                    Body = 'Test',
                    DeveloperName = 'TestTemplateForProjectProcess',
                    IsActive = true
            );
            insert testTemplate;

            EmailMessage testMessage = new EmailMessage(
                    EmailTemplateId = testTemplate.Id,
                    FromAddress = 'test@trailhead.de',
                    ToAddress = 'test@linkedin.de',
                    Status = '3',
                    Subject = 'Das ist ein Test',
                    RelatedToId = oppNew.Id
            );
            insert testMessage;

        }
    }

    @isTest
    static void processEmailValidation_Test(){
        EmailTemplate testTemplate = [SELECT Id FROM EmailTemplate WHERE Name = 'TestTemplateForOppProcess'];
        EmailMessage testMessage = [SELECT Id, RelatedToId FROM EmailMessage LIMIT 1];
        List<Opportunity> testOpps = [SELECT Id, StageName FROM Opportunity ORDER BY Name DESC];
        Map<Id, Opportunity> oldMapOpps = new Map<Id,Opportunity>{testOpps[1].Id => testOpps[0]};
        Map<Id, Opportunity> newMapOpps = new Map<Id,Opportunity>{testOpps[1].Id => testOpps[1]};

        Test.startTest();
        EmailValidation.processEmailValidation(newMapOpps, oldMapOpps, 'StageName');
        Test.stopTest();

        Assert.areEqual(EmailValidationParameter__mdt.getInstance(testOpps[0].StageName).ErrorMessage__c, testOpps[1].getErrors()[0].getMessage());
    }
}
