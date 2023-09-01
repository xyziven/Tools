
MeterSphere(https://github.com/metersphere) is built on top of JMeter. It supports the running of scripts such as beanshell and groovy. In some cases, we may need to call system command for some tasks. 
Given that Java/beanshell is able to call system command, it is also possible for MeterSphere to run system command from its script. Below is the sample to run Python3 script throug calling the system comamnd.

String command = "python3 /opt/metersphere/data/python/test.py";
Runtime rt = Runtime.getRuntime();
Process pr = rt.exec(command);

pr.waitFor();

BufferedReader input = new BufferedReader(new InputStreamReader(pr.getInputStream(), "GBK"));
String line = null;
StringBuilder response = new StringBuilder();
while ((line = input.readLine()) != null) {
  response.append(line + "\\n");
  log.info(line); //print in Console output
}

input.close();

//To save the response data to result, which will be in the request response through post function
vars.put("result",response.toString());

------------
We can also forward the command output to "response body", so that it looks like a normal "api request". We can parse the output from the response body and add some assertions base on needs. Add the following 
code to postprocessor will forward the the output to response body:
r = "${result}";
prev.setResponseData(r);

