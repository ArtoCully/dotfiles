Your goal is to update any vulnerable node dependencies.

Do the following:

1. Create a new Jira ticket by cloning the following ticket VCC-182814
2. The title of the Jira ticket should be "[Co-browsing] - npm audit fix N YYYY-MM-DD"
4. Check out a new branch in this repository with the Jira ticket number just created named 'Security/[Jira-ticket-number]'
3. Run `npm audit` to find vulnerable installed packages in this project
2. Run `npm audit fix` to apply updates
3. Run tests 'npm run test-coverage'
