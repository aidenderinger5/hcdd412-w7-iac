// Subscription-level monthly budget with email alerts at 50% and 90% of actual spend.
// Deploy BEFORE main.bicep:
//   az deployment sub create -l <region> -f budget.bicep -p contactEmails='["you@psu.edu"]'
// Lives at subscription scope, so deleting the resource group does not remove it.
targetScope = 'subscription'

@description('Monthly budget amount in the billing currency.')
param amount int = 10

@description('Alert recipients. Pass at deploy time; do not commit real addresses.')
param contactEmails array

@description('Budget start date: first day of the current month (UTC).')
param startDate string = utcNow('yyyy-MM-01')

resource budget 'Microsoft.Consumption/budgets@2026-06-01' = {
  name: 'budget-hcdd412'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      Actual_GreaterThan_50_Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      Actual_GreaterThan_90_Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 90
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
    }
  }
}
