import chai = require("chai");
import chaiHttp = require("chai-http");

import app = require("./app");

chai.use(chaiHttp);
chai.should();

describe("app", () => {
  it("returns index.html", done => {
    chai
      .request(app)
      .get("/")
      .end((err, res) => {
        chai.assert.isNull(err);
        res.should.have.status(200);
        res.type.should.equal("text/html");
        done();
      });
  });
});
