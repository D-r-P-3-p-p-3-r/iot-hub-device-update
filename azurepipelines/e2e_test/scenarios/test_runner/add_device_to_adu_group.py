# -------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for
# license information.
# --------------------------------------------------------------------------
import sys
# Note: the intention is that this script is called like:
# python ./scenarios/test_runner/testscript.py
sys.path.append('./scenarios/')

sys.path.append('./scenarios/test_runner/')
from scenario_definitions import DuScenarioDefinitionManager
from testingtoolkit import DuAutomatedTestConfigurationManager
from testingtoolkit import DeploymentStatusResponse
from testingtoolkit import UpdateId
from testingtoolkit import DeviceUpdateTestHelper
from testingtoolkit import ADUGroupInfo
import io
import random
import time
import unittest
import xmlrunner
from xmlrunner.extra.xunit_plugin import transform

test_result_file_prefix = ""

class AddDeviceToGroupTest(unittest.TestCase):

    def test_AddDeviceToGroup(self):
        self.aduTestConfig = DuAutomatedTestConfigurationManager.FromOSEnvironment()
        self.duTestHelper = self.aduTestConfig.CreateDeviceUpdateTestHelper()

        self.aduScenarioDefinition = DuScenarioDefinitionManager.FromOSEnvironment()

        test_device_id = self.aduScenarioDefinition.test_device_id
        test_adu_group = self.aduScenarioDefinition.test_adu_group
        global test_result_file_prefix
        test_result_file_prefix = self.aduScenarioDefinition.test_result_file_prefix
        test_connection_timeout_tries = self.aduScenarioDefinition.test_connection_timeout_tries
        retry_wait_time_in_seconds = self.aduScenarioDefinition.retry_wait_time_in_seconds
        config_method = self.aduScenarioDefinition.config_method

        #
        # Before anything else we need to wait and check the device connection status
        # We expect the device to connect within the configured amount of time of setting up the device in the step previous
        #
        connectionStatus = ""
        for i in range(0, test_connection_timeout_tries):
            if config_method == "AIS":
                connectionStatus = self.duTestHelper.GetConnectionStatusForModule(test_device_id, "IoTHubDeviceUpdate")
            else:
                connectionStatus = self.duTestHelper.GetConnectionStatusForDevice(test_device_id)

            if (connectionStatus == "Connected"):
                break
            time.sleep(retry_wait_time_in_seconds)

        self.assertEqual(connectionStatus, "Connected")

        print("ADU Group for device:: " + test_device_id + " Group:: " + test_adu_group)
        #
        # Before we can run the deployment we need to add the ADUGroup test_adu_group tag to the
        # the device before we make the ADUGroup which we can then use to target the deployment
        # to the device.
        #
        if config_method == "AIS":
            success = self.duTestHelper.AddModuleToGroup(
                test_device_id, "IoTHubDeviceUpdate", test_adu_group)
        else:
            success = self.duTestHelper.AddDeviceToGroup(test_device_id, test_adu_group)


        self.assertTrue(success)

        # Creating the group is an async operation with throttling so we want to wait between 2 and 5 minutes so
        # we're not overloading the service.
        random.seed()
        delay_minutes = random.randint(2, 5) # the service has a limit of 6 per 1 minute so we stay between 2 and 5 minutes past that time
        time.sleep(delay_minutes*60)

        for i in range(0, test_connection_timeout_tries):
            adu_group_info = self.duTestHelper.GetAduGroupInfo(test_adu_group)

            if (adu_group_info is not None):
                self.assertEqual(adu_group_info.deviceCount, 1)
                self.assertEqual(adu_group_info.groupId, test_adu_group)
                break

            time.sleep(retry_wait_time_in_seconds)
            continue


if (__name__ == "__main__"):
    out = io.BytesIO()

    unittest.main(testRunner=xmlrunner.XMLTestRunner(output=out),
                  failfast=False, buffer=False, catchbreak=False, exit=False)

    with open('./testresults/' + test_result_file_prefix + 'add-device-to-adu-group-test.xml', 'wb') as report:
        report.write(transform(out.getvalue()))
