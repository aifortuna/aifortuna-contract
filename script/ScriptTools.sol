// SPDX-FileCopyrightText: © 2022 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity >=0.8.0;

import {VmSafe} from "../lib/forge-std/src/Vm.sol";
import {stdJson} from "../lib/forge-std/src/StdJson.sol";

/**
 * @title Script Tools
 * @dev Contains opinionated tools used in scripts.
 */
library ConfigTools {
    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant DEFAULT_DELIMITER = ",";
    string internal constant DELIMITER_OVERRIDE = "DSSTEST_ARRAY_DELIMITER";
    string internal constant EXPORT_JSON_KEY = "EXPORTS";

    // TOOL ENVIRONMENT VARIABLES
    string constant CONFIG_ENV_ROOT_CHAINID = "CONFIG_ENV_ROOT_CHAINID";
    string constant CONFIG_ENV_SCRIPT_CHAININFO = "CONFIG_ENV_SCRIPT_CHAININFO";
    string constant CONFIG_ENV_SCRIPT_APPINFO = "CONFIG_ENV_SCRIPT_APPINFO";
    string constant CONFIG_ENV_SCRIPT_CONFIG_TEXT = "CONFIG_ENV_SCRIPT_CONFIG_TEXT";
    string constant CONFIG_ENV_SCRIPT_CONFIG_NAME = "CONFIG_ENV_SCRIPT_CONFIG_NAME";

    function getRootChainId() internal view returns (uint256) {
        return vm.envUint(CONFIG_ENV_ROOT_CHAINID);
    }

    // e.g. "ethereum-mainnet", "polygon-testnet"
    function getConfigChainInfo() internal view returns (string memory) {
        return vm.envString(CONFIG_ENV_SCRIPT_CHAININFO);
    }

    function getAppInfo() internal view returns (string memory) {
        return vm.envString(CONFIG_ENV_SCRIPT_APPINFO);
    }

    function getConfigName() public view returns (string memory) {
        return vm.envOr(CONFIG_ENV_SCRIPT_CONFIG_NAME, string("defaultConfig"));
    }

    function getInputPath() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string(
            abi.encodePacked(
                root, "/script/input/", getConfigChainInfo(), "/", vm.toString(getRootChainId()), "/", getAppInfo(), "/"
            )
        );
    }

    // TODO: fix/remove app info for script
    function getOutputPath() internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return string(
            abi.encodePacked(
                root,
                "/script/output/",
                getConfigChainInfo(),
                "/",
                vm.toString(getRootChainId()),
                "/",
                getAppInfo(),
                "/"
            )
        );
    }

    function readInput(string memory name) internal view returns (string memory) {
        string memory inputPath = getInputPath();
        return readInput(inputPath, name);
    }

    function readInput(string memory inputPath, string memory name) internal view returns (string memory) {
        return vm.readFile(string(abi.encodePacked(inputPath, name, ".json")));
    }

    function readOutput(string memory name, uint256 timestamp) internal view returns (string memory) {
        string memory outputPath = getOutputPath();
        return vm.readFile(string(abi.encodePacked(outputPath, name, "-", vm.toString(timestamp), ".json")));
    }

    function readOutput(string memory name) internal view returns (string memory) {
        string memory outputPath = getOutputPath();
        return vm.readFile(string(abi.encodePacked(outputPath, name, "-latest.json")));
    }

    /**
     * @notice Use standard environment variables to load config.
     * @dev Will first check CONFIG_ENV_SCRIPT_CONFIG_TEXT for raw json text.
     *      Falls back to CONFIG_ENV_SCRIPT_CONFIG_NAME for a standard file definition.
     *      Finally will fall back to the given string `name`.
     * @param name The default config file to load if no environment variables are set.
     * @return config The raw json text of the config.
     */
    function loadConfig(string memory name) internal view returns (string memory config) {
        config = vm.envOr(CONFIG_ENV_SCRIPT_CONFIG_TEXT, string(""));
        if (eq(config, "")) {
            config = readInput(vm.envOr(CONFIG_ENV_SCRIPT_CONFIG_NAME, name));
        }
    }

    /**
     * @notice Use standard environment variables to load config.
     * @dev Will first check CONFIG_ENV_SCRIPT_CONFIG_TEXT for raw json text.
     *      Falls back to CONFIG_ENV_SCRIPT_CONFIG_NAME for a standard file definition.
     *      Finally will revert if no environment variables are set.
     * @return config The raw json text of the config.
     */
    function loadConfig() internal view returns (string memory config) {
        config = vm.envOr(CONFIG_ENV_SCRIPT_CONFIG_TEXT, string(""));
        if (eq(config, "")) {
            config = readInput(vm.envString(CONFIG_ENV_SCRIPT_CONFIG_NAME));
        }
    }

    /**
     * @notice Use standard environment variables to load dependencies.
     * @dev Will first check FOUNDRY_SCRIPT_DEPS_TEXT for raw json text.
     *      Falls back to FOUNDRY_SCRIPT_DEPS for a standard file definition.
     *      Finally will fall back to the given string `name`.
     * @param name The default dependency file to load if no environment variables are set.
     * @return dependencies The raw json text of the dependencies.
     */
    function loadDependencies(string memory name) internal view returns (string memory dependencies) {
        dependencies = vm.envOr("FOUNDRY_SCRIPT_DEPS_TEXT", string(""));
        if (eq(dependencies, "")) {
            dependencies = readOutput(vm.envOr("FOUNDRY_SCRIPT_DEPS", name));
        }
    }

    /**
     * @notice Use standard environment variables to load dependencies.
     * @dev Will first check FOUNDRY_SCRIPT_DEPS_TEXT for raw json text.
     *      Falls back to FOUNDRY_SCRIPT_DEPS for a standard file definition.
     *      Finally will revert if no environment variables are set.
     * @return dependencies The raw json text of the dependencies.
     */
    function loadDependencies() internal view returns (string memory dependencies) {
        dependencies = vm.envOr("FOUNDRY_SCRIPT_DEPS_TEXT", string(""));
        if (eq(dependencies, "")) {
            dependencies = readOutput(vm.envString("FOUNDRY_SCRIPT_DEPS"));
        }
    }

    /**
     * @notice Used to export important contracts to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Requires FOUNDRY_EXPORTS_NAME to be set.
     * @param label The label of the address.
     * @param addr The address to export.
     */
    function exportContract(string memory label, address addr) internal {
        exportContract(vm.envString("FOUNDRY_EXPORTS_NAME"), label, addr);
    }

    /**
     * @notice Used to export important contracts to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Set FOUNDRY_EXPORTS_NAME to override the name of the json file.
     * @param name The name to give the json file.
     * @param label The label of the address.
     * @param addr The address to export.
     */
    function exportContract(string memory name, string memory label, address addr) internal {
        name = vm.envOr("FOUNDRY_EXPORTS_NAME", name);
        string memory json = vm.serializeAddress(EXPORT_JSON_KEY, label, addr);
        _doExport(name, json);
    }

    /**
     * @notice Used to export important values to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Requires FOUNDRY_EXPORTS_NAME to be set.
     * @param label The label of the address.
     * @param val The value to export.
     */
    function exportValue(string memory label, uint256 val) internal {
        exportValue(vm.envString("FOUNDRY_EXPORTS_NAME"), label, val);
    }

    /**
     * @notice Used to export important values to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Set FOUNDRY_EXPORTS_NAME to override the name of the json file.
     * @param name The name to give the json file.
     * @param label The label of the address.
     * @param val The value to export.
     */
    function exportValue(string memory name, string memory label, uint256 val) internal {
        name = vm.envOr("FOUNDRY_EXPORTS_NAME", name);
        string memory json = vm.serializeUint(EXPORT_JSON_KEY, label, val);
        _doExport(name, json);
    }

    /**
     * @notice Used to export important values to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Requires FOUNDRY_EXPORTS_NAME to be set.
     * @param label The label of the address.
     * @param val The value to export.
     */
    function exportValue(string memory label, string memory val) internal {
        exportValue(vm.envString("FOUNDRY_EXPORTS_NAME"), label, val);
    }

    /**
     * @notice Used to export important values to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Set FOUNDRY_EXPORTS_NAME to override the name of the json file.
     * @param name The name to give the json file.
     * @param label The label of the address.
     * @param val The value to export.
     */
    function exportValue(string memory name, string memory label, string memory val) internal {
        name = vm.envOr("FOUNDRY_EXPORTS_NAME", name);
        string memory json = vm.serializeString(EXPORT_JSON_KEY, label, val);
        _doExport(name, json);
    }

    /**
     * @dev Common logic to export JSON files.
     * @param name The name to give the json file
     * @param json The serialized json object to export.
     */
    function _doExport(string memory name, string memory json) internal {
        string memory outputPath = getOutputPath();
        // Ensure the output directory exists (recursive)
        vm.createDir(outputPath, true);
        vm.writeJson(json, string(abi.encodePacked(outputPath, name, "-", vm.toString(block.timestamp), ".json")));
        if (vm.envOr("FOUNDRY_EXPORTS_OVERWRITE_LATEST", false)) {
            vm.writeJson(json, string(abi.encodePacked(outputPath, name, "-latest.json")));
        }
    }

    /**
     * @notice It's common to define strings as bytes32 (such as for ilks)
     */
    function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory emptyStringTest = bytes(source);
        if (emptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    /**
     * @notice Convert an ilk to a chainlog key by replacing all dashes with underscores.
     *         Ex) Convert "ETH-A" to "ETH_A"
     */
    function ilkToChainlogFormat(bytes32 ilk) internal pure returns (string memory) {
        uint256 len = 0;
        for (; len < 32; len++) {
            if (uint8(ilk[len]) == 0x00) break;
        }
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            uint8 b = uint8(ilk[i]);
            if (b == 0x2d) result[i] = bytes1(0x5f);
            else result[i] = bytes1(b);
        }
        return string(result);
    }

    function eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    // =====================
    // Decimal string parsing
    // =====================
    /// @notice Parse a base-10 decimal string into an integer scaled by `decimals`.
    /// @dev Supports formats like "123", "123.45", ".5", "1.". Extra fractional digits beyond
    ///      `decimals` are truncated (not rounded).
    /// @param s The decimal string to parse (no sign, no scientific notation).
    /// @param decimals The number of decimals to scale to (e.g., 18 for wad).
    /// @return result The scaled integer value.
    function parseDecimal(string memory s, uint8 decimals) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        require(b.length > 0, "empty decimal");

        uint256 intPart = 0;
        uint256 fracPart = 0;
        uint8 fracDigits = 0;
        bool seenDot = false;
        bool seenDigit = false;

        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x2e) {
                // '.'
                require(!seenDot, "multiple dots");
                seenDot = true;
                continue;
            }
            require(c >= 0x30 && c <= 0x39, "invalid char");
            seenDigit = true;
            uint8 d = uint8(c) - 48; // '0' = 48
            if (!seenDot) {
                intPart = intPart * 10 + d;
            } else if (fracDigits < decimals) {
                fracPart = fracPart * 10 + d;
                unchecked {
                    fracDigits++;
                }
            } else {
                // truncate extra digits beyond `decimals`
            }
        }

        require(seenDigit, "no digits");

        // scale fractional part up to `decimals`
        if (fracDigits < decimals) {
            uint256 missing = decimals - fracDigits;
            uint256 scale = _pow10(missing);
            fracPart = fracPart * scale;
        }

        result = intPart * _pow10(decimals) + fracPart;
    }

    /// @notice Parse a decimal string into 18-decimal fixed point (WAD).
    function parseWad(string memory s) internal pure returns (uint256) {
        return parseDecimal(s, 18);
    }

    /// @dev 10^n for small n (n <= 77 is safe in 256-bit; we use <= 18).
    function _pow10(uint256 n) private pure returns (uint256 r) {
        r = 1;
        while (n > 0) {
            r *= 10;
            unchecked {
                n--;
            }
        }
    }

    // Read config variable, but allow for an environment variable override

    function readUint(string memory json, string memory key, string memory envKey) internal view returns (uint256) {
        return vm.envOr(envKey, stdJson.readUint(json, key));
    }

    function readUintArray(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (uint256[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readUintArray(json, key));
    }

    function readInt(string memory json, string memory key, string memory envKey) internal view returns (int256) {
        return vm.envOr(envKey, stdJson.readInt(json, key));
    }

    function readIntArray(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (int256[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readIntArray(json, key));
    }

    function readBytes32(string memory json, string memory key, string memory envKey) internal view returns (bytes32) {
        return vm.envOr(envKey, stdJson.readBytes32(json, key));
    }

    function readBytes32Array(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (bytes32[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readBytes32Array(json, key));
    }

    function readString(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (string memory)
    {
        return vm.envOr(envKey, stdJson.readString(json, key));
    }

    function readStringArray(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (string[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readStringArray(json, key));
    }

    function readAddress(string memory json, string memory key, string memory envKey) internal view returns (address) {
        return vm.envOr(envKey, stdJson.readAddress(json, key));
    }

    function readAddressArray(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (address[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readAddressArray(json, key));
    }

    function readBool(string memory json, string memory key, string memory envKey) internal view returns (bool) {
        return vm.envOr(envKey, stdJson.readBool(json, key));
    }

    function readBoolArray(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (bool[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readBoolArray(json, key));
    }

    function readBytes(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (bytes memory)
    {
        return vm.envOr(envKey, stdJson.readBytes(json, key));
    }

    function readBytesArray(string memory json, string memory key, string memory envKey)
        internal
        view
        returns (bytes[] memory)
    {
        return vm.envOr(envKey, vm.envOr(DELIMITER_OVERRIDE, DEFAULT_DELIMITER), stdJson.readBytesArray(json, key));
    }
}
