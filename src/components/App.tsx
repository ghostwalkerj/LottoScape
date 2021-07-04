import React, { Component } from "react";
import Web3 from "web3";
import "./App.css";
import Decentragram from "../abis/Decentragram.json";
import Navbar from "./Navbar";
import Main from "./Main";

export type FixMeLater = any;

class App extends React.Component<any, any> {
  constructor(props: any) {
    super(props);
    this.state = {
      account: ""
    };
  }

  render() {
    return (
      <div>
        <Navbar account={this.state.account} />
        {this.state.loading ? (
          <div id="loader" className="text-center mt-5">
            <p>Loading...</p>
          </div>
        ) : (
          <Main
          // Code...
          />
        )}
      </div>
    );
  }
}

export default App;
