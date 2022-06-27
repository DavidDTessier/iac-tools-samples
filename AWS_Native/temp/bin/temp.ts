#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { TempStack } from '../lib/temp-stack';

const app = new cdk.App();
new TempStack(app, 'TempStack');
