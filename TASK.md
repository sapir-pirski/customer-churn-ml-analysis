# Python Project – Part A

In this project each team (up to 3 members) will receive a dataset and will create a full solution including a presentation (PP – Power Point) about the problem the team tried to solve.

The presentation and notebook used to create it must be submitted together.

All the conclusions and visualization in the PP must be implemented in the notebook.

## Dataset:

| Dataset | Description |
| --- | --- |
| Churn | Predict whether a customer will churn (the loss of clients or customers) |

## Files:

In addition to this document please find below files:

1. **Datasets** – includes the above dataset
2. **Titanic example** – 3 notebooks + the titanic dataset csv file (before preprocessing) with examples on how to do this project.

## Presentation:

The presentation should include the following aspects:

1. Names and IDs of all team members
2. The problem:

   - what are you trying to predict?
   - What data is available for that (input)?
   - What can be the motivation and applications for solving the problem?

3. Data description:

   - How many examples are in the dataset? (train/test)
   - How many features are in the dataset?
   - What is the distribution of the labels?
   - Are there any missing values?
   - Show 5-6 graphs describing various aspects of the data

4. Data engineering:

   - Did you remove any features?
   - Did you add any features?
   - What did you do with missing values?

5. ML Algorithms: test the following algorithms:

   - K nearest neighbors, try different k values
   - Decision tree with different max depth values
   - Random Forest with different max depth values and different estimators

6. Algorithms introspection – inspect the various algorithms artifacts:

   - What decision trees did you get?
   - What is the random forest feature importance?
   - Plot the best accuracy for all algorithms (train & test)

## Churn Dataset Fields:

| Field | Description |
| --- | --- |
| `customerID` | Customer ID |
| `gender` | Whether the customer is a male or a female |
| `SeniorCitizen` | Whether the customer is a senior citizen or not |
| `Partner` | Whether the customer has a partner or not |
| `Dependents` | Whether the customer has dependents or not |
| `tenure` | Number of months the customer has stayed with the company |
| `PhoneService` | Whether the customer has a phone service or not |
| `MultipleLines` | Whether the customer has multiple lines or not |
| `InternetService` | Customer's internet service provider |
| `OnlineSecurity` | Whether the customer has online security or not |
| `OnlineBackup` | Whether the customer has online backup or not |
| `DeviceProtection` | Whether the customer has device protection or not |
| `TechSupport` | Whether the customer has tech support or not |
| `StreamingTV` | Whether the customer has streaming TV or not |
| `StreamingMovies` | Whether the customer has streaming movies or not |
| `Contract` | The contract term of the customer |
| `PaperlessBilling` | Whether the customer has paperless billing or not |
| `PaymentMethod` | The customer’s payment method |
| `MonthlyCharges` | The amount charged to the customer monthly |
| `TotalCharges` | The total amount charged to the customer |
| `Churn` | Whether the customer churned or not (Yes or No) |
