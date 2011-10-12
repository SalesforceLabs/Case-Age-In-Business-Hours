trigger CalculateBusinessHoursAges on Case (before insert, before update) {
    if (Trigger.isInsert) {
        for (Case updatedCase:System.Trigger.new) {
            updatedCase.Last_Status_Change__c = System.now();
            updatedCase.Time_With_Customer__c = 0;
            updatedCase.Time_With_Support__c = 0;
        }
    } else {
        //Get the stop statuses
        Set<String> stopStatusSet = new Set<String>();
        for (Stop_Status__c stopStatus:[Select Name From Stop_Status__c]) {
            stopStatusSet.add(stopStatus.Name);
        }

        //Get the default business hours (we might need it)
        BusinessHours defaultHours = [select Id from BusinessHours where IsDefault=true];

        //Get the closed statuses (because at the point of this trigger Case.IsClosed won't be set yet)
        Set<String> closedStatusSet = new Set<String>();
        for (CaseStatus status:[Select MasterLabel From CaseStatus where IsClosed=true]) {
            closedStatusSet.add(status.MasterLabel);
        }

        //For any case where the status is changed, recalc the business hours in the buckets
        for (Case updatedCase:System.Trigger.new) {
            Case oldCase = System.Trigger.oldMap.get(updatedCase.Id);

            if (oldCase.Status!=updatedCase.Status && updatedCase.Last_Status_Change__c!=null) {
                //OK, the status has changed
                if (!oldCase.IsClosed) {
                    //We only update the buckets for open cases

					//On the off-chance that the business hours on the case are null, use the default ones instead
                    Id hoursToUse = updatedCase.BusinessHoursId!=null?updatedCase.BusinessHoursId:defaultHours.Id;

                    //The diff method comes back in milliseconds, so we divide by 3600000 to get hours.
                    Double timeSinceLastStatus = BusinessHours.diff(hoursToUse, updatedCase.Last_Status_Change__c, System.now())/3600000.0;
                    System.debug(timeSinceLastStatus);

                    //We decide which bucket to add it to based on whether it was in a stop status before
                    if (stopStatusSet.contains(oldCase.Status)) {
                        updatedCase.Time_With_Customer__c += timeSinceLastStatus;
                    } else {
                        updatedCase.Time_With_Support__c += timeSinceLastStatus;
                    }

					if (closedStatusSet.contains(updatedCase.Status)) {
                    	updatedCase.Case_Age_In_Business_Hours__c = updatedCase.Time_With_Customer__c + updatedCase.Time_With_Support__c;
					}
                }

                updatedCase.Last_Status_Change__c = System.now();
            }
        }
    }
}