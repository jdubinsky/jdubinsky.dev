import express from "express";
import path from "path";

const app = express();
const port = process.env.APP_PORT;

app.use("/static", express.static(path.join(__dirname, "static")));

app.get("/", (request: express.Request, response: express.Response) => {
  const indexPath = path.join(__dirname, "/index.html");
  return response.sendFile(indexPath);
});

app.listen(port, () => console.log(`Now listening on port ${port}`));

export default app;
