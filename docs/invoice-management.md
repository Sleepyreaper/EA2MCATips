# Invoice Management under MCA

## Invoice structure

Under MCA, a monthly invoice is generated per billing profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)). Each invoice section appears on the invoice and shows charges for the subscriptions and purchases assigned to that section ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-section-invoice)). The invoice provides a summary of charges and payment instructions and is downloadable as a PDF ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-understand-your-invoice)).

## Invoice timing after EA to MCA migration

Microsoft Learn says the new MCA invoice is generated on the fifth day of the month after migration, and the first MCA invoice may contain a partial charge from the migration date ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-understand-your-invoice)). Finance and reconciliation automation should account for final EA invoicing through the migration date and partial first-period MCA charges.

## Portal retrieval

MCA invoices are available from the Azure portal through Cost Management + Billing and can be downloaded as PDFs ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-understand-your-invoice)). Microsoft Learn also provides general invoice download guidance for Azure billing ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/download-azure-invoice)).

## API retrieval

The Billing REST API provides invoice operations, including list and download ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/invoices?view=rest-billing-2024-04-01)). The documented download endpoint pattern is:

```http
POST /providers/Microsoft.Billing/billingAccounts/{billingAccountName}/invoices/{invoiceName}/download?api-version=2020-05-01&downloadToken={downloadToken}
```

Source: [Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/invoices/download-invoice?view=rest-billing-2020-05-01)

## Least-privilege role for invoice retrieval

Current Learn language supports Billing profile Owner, Contributor, Reader, or Invoice manager for viewing billing information under MCA. For invoice-specific retrieval/download, **Invoice manager** is the narrowest documented billing role ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/download-azure-invoice-daily-usage-date)). Because Learn does not present one canonical minimum-per-action permission matrix for every invoice operation, validate invoice download in the customer tenant before broad rollout.
