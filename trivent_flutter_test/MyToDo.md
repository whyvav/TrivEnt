# Issues
## Priority 1
- Make the app more general: Option to "Add Company". Currently it is hardcoded as Triveni Enterprises, and the corresponding data (the only data so far) is of that company. But, I want the app to be usable by other related manufacturing businesses. Also, one user (logged in) can have multiple companies as well, that he would like to switch between. (There could be an option on the Dashboard itself to click on the company name, and be able to choose a different one or add a new one). How would the "general manufacturing ERP app" would work? (Make a plan first and then start work in that direction, making the crucial first changes and letting me know what I need to do/understand -- e.g., in Firestore, etc.) The multiple companies option for like a current logged in user -- do that simply. The main things that would change once 

- The Transactions on the Party Detail screen needs to be clickable (leading to the respective Sales, Purchases, Pay-in, Pay-out, etc.

- Party Detail screen: address length overflow

-DONE: Icon, bar, and text size in the Desktop view to be increased.

- In Parties: Three categories (Customer, Vendor, Labor)
- Inventory: one more category for Other (e.g., to track Assets like machine equipment, Utilities like Diesel)

- Manufacture: Other costs (listed in BoM) should be appropriately and automatically added to Expenses as a transaction (and in connected calculations, Reports)

- Two types of Staff/Laborers: Contractual, Work-based
-- Contractual one directly from BoM (per unit Labor cost times number of bricks manufactured). Work-based is based on number of days worked (a counter/attendance against their name)


## Priority 3
- Login screen: Clicking Enter (from the password box) should "click" on the Login button
