# -*- coding: utf-8 -*-
"""
Created on Sat Dec  5 14:24:39 2020

@author: nicol
"""
#### Loading necessary packages and reading in data
import warnings
warnings.filterwarnings('ignore')
import pandas as pd
import numpy as np
import matplotlib
import matplotlib.font_manager as font_manager
import matplotlib.pyplot as plt
import seaborn as sns


fontpath = 'Lato-Regular.ttf'

prop = font_manager.FontProperties(fname=fontpath)
matplotlib.rcParams['font.family'] = prop.get_name()

accounts = pd.read_csv("data/accounts_analytical.csv")

transactions = pd.read_csv("data/transactions.csv")


#### Setting up the data frame
# Getting average balance for each account from the transactions data
avg_balDF = (transactions
             .groupby('account_id', as_index=False)
             .agg({'balance': 'mean'})
             .rename(columns={'balance':'avg_balance'}))

# Creating columns for whether or not the account uses credit cards or loans,
# then adding the average balance
cc_loansDF = accounts.assign(
    cc_user = np.where(pd.isna(accounts['credit_cards']), 'No Credit Cards', 'Has Credit Card(s)'),
    loan_user = np.where(pd.isna(accounts['loan_date']), 'No Loans', 'Has Loan(s)'))

cc_loansDF = cc_loansDF[['account_id', 'cc_user', 'loan_user']]

cc_loans_balDF = cc_loansDF.merge(avg_balDF)


#### Plotting faceted histograms
p = sns.FacetGrid(cc_loans_balDF, col="cc_user",
                  row="loan_user", margin_titles=True)
p = p.map_dataframe(sns.histplot, x="avg_balance", bins=20)
p = p.set_axis_labels("Average Balance", "Frequency")
#p.fig.suptitle('Account Average Balance by Loan and Credit Card Use') 


# Fixing the titles to be like ggplot
p = p.set_titles(row_template = '{row_name}', col_template = '{col_name}')

plt.subplots_adjust(top=0.9, left=0.1, bottom=0.1) # The axes titles were getting cut off without this
plt.suptitle('Account Average Balance by Loan and Credit Card Use')
plt.show()



    
######## seaborn-white

