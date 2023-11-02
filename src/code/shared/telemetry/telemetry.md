# Telemetry

In this context telemtetry is more about collecting different datapoints for our solution that could help to understand any issues that may arise. seeing as this solutuion is quite big in size for a pwsh solution, it is very important to have the proper logging/datapoints to help improve any issues or bugs that may arise.



## is this sent somewhere?
No, not at the moment.

It is planned to have some datapoints sent out to a central location (run times, what resources are deployed/api versions. mabye even error messages?), however this would have to be implemented in such a way that it does not impact the performance of the solution, is not a seurity risk and is not a privacy concern for any involved parties. (if it where to be implemented it would be a totally open and opt in process). on the flip side of this would a generally really good estimate of how long a deployment would take, and possibly even a way to see if there are any common issues with using these specific resources.