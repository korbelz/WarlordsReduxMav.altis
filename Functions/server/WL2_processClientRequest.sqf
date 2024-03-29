#include "..\warlords_constants.inc"

params ["_var", "_action"];

private _sender = objNull;
private _actionArray = _action splitString "|";
_action = _actionArray # 0;
private _params = _actionArray - [_action];

if (isMultiplayer) then {
	_var = (_var splitString "BIS_WL_") # 0;

	private _senderArr = BIS_WL_allWarlords select {getPlayerUID _x == _var};
	if (count _senderArr == 0) exitWith {};

	_sender = _senderArr # 0;
} else {
	_sender = player;
};

_processTargetPos = {
	private _targetPosFinalArr = [];
	private _targetPosFinal = [];
	
	if !(surfaceIsWater _targetPos) then {
		_nearSectorArr = _targetPos nearObjects ["Logic", 10]; 
		
		if (count _nearSectorArr == 0) then {
			_targetPosFinalArr = [_sender, nil, FALSE, _sender] call BIS_fnc_WL2_findSpawnPositions;
		} else {
			_sector = _nearSectorArr # 0;
			_targetPosFinalArr = [_sector, nil, FALSE, if (_sender inArea (_sector getVariable "objectAreaComplete")) then {_sender}] call BIS_fnc_WL2_findSpawnPositions;
		};
	} else {
		_targetPosFinalArr = [_targetPos];
	};

	if (count _targetPosFinalArr > 0) then {
		_targetPosFinal = selectRandom _targetPosFinalArr;
	} else {
		_targetPosFinal = [_targetPos, random 10, random 100] call BIS_fnc_relPos;
	};
	
	[_targetPosFinal, _targetPosFinalArr]
};

_setOwner = {
	params ["_asset", "_sender", ["_isStatic", FALSE]];
	if (_asset isKindOf "Man") exitWith {};
	if (isMultiplayer) then {
		if !(_isStatic) then {
			waitUntil {sleep WL_TIMEOUT_SHORT; {uniform _x == "U_VirtualMan_F"} count crew _asset == 0};
		};
		_i = 0;
		if (count crew _asset > 0 && _isStatic) then {
			_assetGrp = group effectiveCommander _asset;
			while {!(_assetGrp setGroupOwner (owner _sender)) && _i < 50} do {
				_i = _i + 1;
				_assetGrp setGroupOwner (owner _sender);
				sleep WL_TIMEOUT_SHORT;
			};
		};
		_i = 0;
		while {!(_asset setGroupOwner (owner _sender)) && (owner _asset) != (owner _sender) && _i < 50} do {
			_i = _i + 1;
			_asset setGroupOwner (owner _sender);
			sleep WL_TIMEOUT_SHORT;
		};
	};
};

if !(isNull _sender) then {
	switch (_action) do {
		case "respawn": {
			_sender setDamage 1
		};
		case "requestAsset": {
			_params params ["_assetVar", "_className", "_targetPos", "_isStatic", "_disable"];
			private _asset = objNull;
			
			private _isStatic = call compile _isStatic;
			private _disable = call compile _disable;
			
			_targetPos = call compile _targetPos;
			_targetPosFinal = if (_isStatic) then {_targetPos} else {(call _processTargetPos) # 0};
			
			if (_className isKindOf "Ship") then {
				_asset = createVehicle [_className, _targetPosFinal, [], 0, "CAN_COLLIDE"];
				_asset setPos (_targetPosFinal vectorAdd [0,0,3]);
				
			} else {
				if (_className isKindOf "Air") then {
					_isPlane = (toLower getText (configFile >> "CfgVehicles" >> _className >> "simulation")) in ["airplanex", "airplane"] && !(_className isKindOf "VTOL_Base_F");
					if (_isPlane) then {
						private _sector = ((_targetPos nearObjects ["Logic", 10]) select {count (_x getVariable ["BIS_WL_runwaySpawnPosArr", []]) > 0}) # 0;
						private _taxiNodes = _sector getVariable "BIS_WL_runwaySpawnPosArr";
						private _taxiNodesCnt = count _taxiNodes;
						private _spawnPos = [];
						//private _dir = getDir _sender;
						private _checks = 0;
						while {count _spawnPos == 0 && _checks < 100} do {
							_checks = _checks + 1;
							private _i = (floor random _taxiNodesCnt) max 1;
							private _pointB = _taxiNodes # _i;
							private _pointA = _taxiNodes # (_i - 1);
							//_dir = _pointA getDir _pointB;
							private _pos = [_pointA, random (_pointA distance2D _pointB), _dir] call BIS_fnc_relPos;
							if (count (_pos nearObjects ["AllVehicles", 20]) == 0) then {
								_spawnPos = _pos;
							}
						};
						//"Air spawn code running" remoteExec ["systemChat"];
						if (count _spawnPos == 0) then {
							_spawnPos = _targetPosFinal;
						};
						_asset = createVehicle [_className, ((position _sender) vectorAdd [0,400,200]), [], 0, "FLY"];
						//_asset setDir _dir;
						_sender moveInDriver _asset;
						//_asset = createVehicle [_className, _spawnPos, [], 0, "CAN_COLLIDE"];
						
						if (KORB_AIR_RADAR_ACTIVE == 1) then {
							_asset enableVehicleSensor ["ActiveRadarSensorComponent", false];
							_asset enableVehicleSensor ["PassiveRadarSensorComponent", false];
						};
						if (KORB_JET_IR_ACTIVE == 1) then {
							_asset disableTIEquipment true;
						}; 

						if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == WEST) then {
							createVehicleCrew _asset;
							
							//"Bluefor air crew spawn code running" remoteExec ["systemChat"];
						};
						if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == EAST) then {
							createVehicleCrew _asset;
							_assetUavGrp = createGroup EAST;
							[driver _asset, gunner _asset] joinSilent _assetUavGrp;
																	
							//"OPFOR air crew spawn code running" remoteExec ["systemChat"];
						};
					} else {
						_asset = createVehicle [_className, _targetPosFinal, [], 0, "FLY"]; //heli spawn code, need anti-building check added. WARNING! messing with this code block breaks fast travel...I have no damn clue why.
						_asset setVelocity [0, 0, 0];
						[_asset, _sender] call BIS_fnc_WL2_sub_assetLanding;
						if (KORB_HELI_IR_ACTIVE == 1) then {
							_asset disableTIEquipment true;
						};
						if (KORB_HELI_RADAR_ACTIVE == 1) then {
							_asset enableVehicleSensor ["ActiveRadarSensorComponent", false];
							_asset enableVehicleSensor ["PassiveRadarSensorComponent", false];
						};
						if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == WEST) then {
							createVehicleCrew _asset;
							"You must unlock UAV via the I menu to fly it" remoteExec ["systemChat"];
							//"Blufor heli crew spawn code running" remoteExec ["systemChat"];
						};
						if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == EAST) then {
								createVehicleCrew _asset;
								_assetUavGrp = createGroup EAST;
								[driver _asset, gunner _asset] joinSilent _assetUavGrp;
								"You must unlock UAV via the I menu to fly it" remoteExec ["systemChat"];			
								//"OPFOR heli crew spawn code running" remoteExec ["systemChat"];
						};
						//_text = format ["thing I spawned is: %1 and bought by: %2", _asset, _sender];
						//[_text] remoteExec ["systemChat"];
						//"Heli spawn code running" remoteExec ["systemChat"];
					};
				} else {
					if (_isStatic) then {
						_asset = createVehicle [_className, _targetPosFinal, [], 0, "NONE"];
						_targetPos set [2, (_targetPos # 2) max 0];
						_asset setDir direction _sender;
						_asset setPos _targetPosFinal;
						if (_disable) then {
							_asset enableSimulationGlobal FALSE;
							_asset hideObjectGlobal TRUE;
						} else {
							if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == WEST) then {
								createVehicleCrew _asset;
								(effectiveCommander _asset) setSkill 1;
								(group effectiveCommander _asset) deleteGroupWhenEmpty TRUE;
								//"Blufor static crew spawn code running" remoteExec ["systemChat"];
							};
							if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == EAST) then {
								createVehicleCrew _asset;
								_assetUavGrp = createGroup EAST;
								[driver _asset, gunner _asset] joinSilent _assetUavGrp;
										
								(effectiveCommander _asset) setSkill 1;
								(group effectiveCommander _asset) deleteGroupWhenEmpty TRUE;
								//"OPFOR static crew spawn code running" remoteExec ["systemChat"];
							};
						};
						//"isStatic spawn code running" remoteExec ["systemChat"];
					};
				};
			};
			
			_asset setVehicleVarName _assetVar;
			missionNamespace setVariable [_assetVar, _asset];
			(owner _sender) publicVariableClient _assetVar;
			
			[_asset, _sender, _isStatic] spawn _setGroupOwner;
		};
		case "requestAssetArray": {
			_params params ["_assetVar", "_infoArray", "_targetPos"];
			private _assets = [];

			_infoArray = call compile _infoArray;
			_targetPos = call compile _targetPos;
			_purchaseList = missionNamespace getVariable format ["BIS_WL_purchasable_%1", side group _sender];
			_classNames = [];
			_assets = [];
			
			{
				if ((_forEachIndex % 2) == 0) then {
					_category = _x;
					_item = _infoArray # (_forEachIndex + 1);
					_classNames pushBack (((_purchaseList # _category) # _item) # 0);
				};
			} forEach _infoArray;
			
			_targetPosArr = (call _processTargetPos) # 1;
			
			{
				_className = _x;
				_isMan = _className isKindOf "Man";
				_targetPosFinal = if (_className isKindOf "Air") then {
					if (count _targetPosArr > 10) then {
						selectRandom _targetPosArr
					} else {
						(call _processTargetPos) # 0
					};
				} else {
					if (_forEachIndex < count _targetPosArr) then {
						_targetPosArr # _forEachIndex;
					} else {
						(call _processTargetPos) # 0;
					};
				};
				
				private _asset = objNull;
				_parachute = createVehicle [if (_isMan) then {"Steerable_Parachute_F"} else {"B_Parachute_02_F"}, _targetPosFinal, [], 0, "FLY"];
				//called in Inf and Vehicle spawning code. Inf = _isMan, Vic = Else 
				if (_isMan) then {
					_asset = (group _sender) createUnit [_className, _targetPosFinal, [], 0, "NONE"];
					_asset assignAsDriver _parachute;
					_asset moveInDriver _parachute;
					[_parachute, _asset] spawn {
						params ["_parachute", "_asset"];
						waitUntil {sleep WL_TIMEOUT_STANDARD; isNull _parachute || isNull _asset};
						if (isNull _asset) then {
							deleteVehicle _parachute;
						};
					}; 
				} else {
							
					_parachute setPos ((position _parachute) vectorAdd [0, 0, KORB_VIC_MIN_HEIGHT + random KORB_VIC_RANDOM_HEIGHT]);
					_asset = createVehicle [_className, _targetPosFinal, [], 0, "NONE"];
					_asset setVariable ["BIS_WL_deployPos", _targetPosFinal];
					_bBox = boundingBoxReal _asset;
					_bBoxCenter = (_bbox # 0) vectorAdd (_bBox # 1);
					_asset attachTo [_parachute, _bBoxCenter];
					_assetDummy = _className createVehicleLocal _targetPosFinal;
					_assetDummy setPos _targetPosFinal;
					_assetDummy hideObject TRUE;
					_assetDummy enableSimulation TRUE;
					if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == WEST) then {
								createVehicleCrew _asset;
								(effectiveCommander _asset) setSkill 1;
								(group effectiveCommander _asset) deleteGroupWhenEmpty TRUE;
								//"Blufor static crew spawn code running" remoteExec ["systemChat"];
							};
							if (getNumber (configFile >> "CfgVehicles" >> _className >> "isUav") == 1 && side _sender == EAST) then {
								createVehicleCrew _asset;
								_assetUavGrp = createGroup EAST;
								[driver _asset, gunner _asset] joinSilent _assetUavGrp;
										
								(effectiveCommander _asset) setSkill 1;
								(group effectiveCommander _asset) deleteGroupWhenEmpty TRUE;
								//"OPFOR static crew spawn code running" remoteExec ["systemChat"];
							};
					if (KORB_TANK_IR_ACTIVE == 1) then {
						_asset disableTIEquipment true;
					};
					//"Vic spawn code running" remoteExec ["systemChat"];

					[_parachute, _asset, _assetDummy] spawn {
						params ["_parachute", "_asset", "_assetDummy"];
						
						while {alive _parachute && alive _asset && (position _asset) # 2 >= 4} do {
							_parachute setVelocity [0, 0, (velocity _parachute) # 2];
							_parachute setVectorUp [0,0,1];
							sleep 0.25;
						};
						
						deleteVehicle _assetDummy;
						
						if (isNull _asset) then {
							deleteVehicle _parachute;
						} else {
							detach _asset;
							_parachute disableCollisionWith _asset;
							_itemConfig = configFile >> "CfgVehicles" >> typeOf _asset;
							_dropSoundClassArr = getArray (_itemConfig >> "soundBuildingCrash");
							_dropSoundArr = [];
							// this code block waits for the vic to 'land' then repair and refuels it.
							sleep 2;
							_asset setDamage 0;
							_asset setFuel 1;
							//"vic repair code running" remoteExec ["systemChat"];
							
							{
								if (_forEachIndex % 2 == 0) then {
									_dropSoundArr pushBack ((getArray (_itemConfig >> _x)) # 0);
								};
							} forEach _dropSoundClassArr;
							
							if (count _dropSoundArr > 0) then {
								_dropSound = selectRandom _dropSoundArr;
								sleep 0.75;
								playSound3D [_dropSound + ".wss", _asset];
							};
						};
					};
				};
				
				_assetVariable = call BIS_fnc_WL2_generateVariableName;
				_asset setVehicleVarName _assetVariable;
				missionNamespace setVariable [_assetVariable, _asset];
				if (isMultiplayer) then {
					[_asset, _assetVariable] remoteExec ["setVehicleVarName", _sender];
				};
				_assets pushBack _asset;
				
				[_asset, _sender] spawn _setGroupOwner;
				
				
			} forEach _classNames;
			
			missionNamespace setVariable [_assetVar, _assets];
			(owner _sender) publicVariableClient _assetVar;
		};
		case "deleteAsset": {
			_params params ["_assetVar"];
			_asset = missionNamespace getVariable [_assetVar, objNull];
			_asset call BIS_fnc_WL2_sub_deleteAsset;
		};
		case "repairAsset": {
			_params params ["_assetVar"];
			_asset = missionNamespace getVariable [_assetVar, objNull];
			_asset setDamage 0;
		};
		case "fundsTransfer": {
			_params params ["_recipient", "_amount"];
			_recipientArr = BIS_WL_allWarlords select {getPlayerUID _x == _recipient};
			_amount = parseNumber _amount;
			if (count _recipientArr > 0) then {
				_recipient = _recipientArr # 0;
				[_sender, -_amount] call BIS_fnc_WL2_fundsControl;
				[_recipient, _amount] call BIS_fnc_WL2_fundsControl;
			};
		};
		case "fastTravel": {
			_params params ["_destination"];
			_destination = parseSimpleArray _destination;
			[_sender, _destination] spawn {
				params ["_sender", "_destination"];
				private _tagAlong = (units group _sender) select {_x distance2D _sender <= WL_FAST_TRAVEL_TEAM_RADIUS && vehicle _x == _x};
				while {_tagAlong findIf {_x distance2D _destination > 50 && alive _x} != -1} do {
					private _toMove = _tagAlong select {_x distance2D _destination > 50 && alive _x};
					{
						[_x, [_destination, [], 2, "NONE"]] remoteExec ["setVehiclePosition", _x];
					} forEach _toMove;
					sleep WL_TIMEOUT_STANDARD;
				};
			};
		};
	};
};

if !(isMultiplayer) then {
	missionNamespace setVariable [_var, ""];
};