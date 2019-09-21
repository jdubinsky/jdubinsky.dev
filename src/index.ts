import app from "./app";

const port = process.env.APP_PORT;
const isInLambda = !!process.env.LAMBDA_TASK_ROOT;

if (isInLambda) {
  const serverlessExpress = require("aws-serverless-express");
  const server = serverlessExpress.createServer(app);
  exports.handler = (event: any, context: any) =>
    serverlessExpress.proxy(server, event, context);
} else {
  app.listen(port, () => console.log(`Listening on port ${port}`));
}
