#!/usr/bin/swift

import Foundation

main()

/* * *
*   Determine what AC to expect at the given CR/level
*   - CR: Challenge Rating or Level of the opponent
* * */
func getACforCR(CR: Int) -> Int {
	// Average AC generally follows a trend of advancing with CR, increasing by an additional 1 every 4 levels (hence CR*5/4) and another 1 on levels 6, 10, 14, 18 and 19 (except for CR -1) according to [a survey of Bestiary 1](https://docs.google.com/spreadsheets/d/1VQdXIJMMeNlkL1ta_b9q_iImAHoujDCYs1WaBJP-Rjs/edit#gid=415731613)

	switch (CR) {
		case -1: return 16
		case 0...5: return (CR*5/4)+16
		case 6...9: return (CR*5/4)+17
		case 10...13: return (CR*5/4)+18
		case 14...17: return (CR*5/4)+19
		case 18: return (CR*5/4)+20
		default: return (CR*5/4)+21
	}
}

/* * *
* Calculate the average result of a dice roll.
* - roll string should be provided like "2d8+3" (meaning we roll 2 8-sided dice, add their results and add another 3) or "7d4-2" (roll 7 4-sided dice, add their results and subtract 2). The part behind the "+" (or "-") sign may be expressed as an arithmatic formula (like "6-4") for conveniance. Parsing errors will result in a return value of -99.0 along with an error prompt. If the input is a fixed value that can be interpreted as a floating point number (such as "5"), it will be returned.
* * */
func parseDice(rollArray: [String]) -> Double {
    var avgResult = 0.0
    for roll in rollArray {
        let rolls=roll.split(separator: "d")
        let numberFormatter = NumberFormatter()
        switch (rolls.count) {
            case 0:
                print("Syntax error. Could not parse \(roll): Splitting the input resulted in an empty array.")
                return -99.0
            case 1:
                let floatVal = numberFormatter.number(from: (String)(rolls[0]))
                if (floatVal != nil) {
                    return floatVal as! Double
                } else {
                    print("Syntax error. Could not parse \(roll): Unable to split the input and it doesn't look like a floating point number.")
                    return -99.0
                }
            case 2:
                let NSdiceCount = numberFormatter.number(from: (String)(rolls[0]))
                if (NSdiceCount == nil) {
                    print("Syntax error. Could not parse \(roll): Number of dice to roll doesn't look like a number.")
                    return -99.0
                }
                let diceCount = NSdiceCount as! Double

                let posModifierIndex = (String)(rolls[1]).firstIndex(of: "+") ?? nil
                let negModifierIndex = (String)(rolls[1]).firstIndex(of: "-") ?? nil
                var modifierIndex: String.Index
                if (posModifierIndex != nil) {
                    if (negModifierIndex != nil) {
                        modifierIndex = min(posModifierIndex!, negModifierIndex!)
                    } else {
                        modifierIndex = posModifierIndex!
                    }
                } else if (negModifierIndex != nil) {
                    modifierIndex = negModifierIndex!
                } else {
                    modifierIndex = (String)(rolls[1]).endIndex
                }
                let dieSize = Int((String)(rolls[1])[..<modifierIndex]) ?? -1
                var expectedRoll = 0.5+(Double(dieSize)/2.0)

                expectedRoll *= diceCount
                if (modifierIndex < (String)(rolls[1]).endIndex) {
                    let modifier = NSExpression(format: "0"+(String)((String)(rolls[1])[modifierIndex..<(String)(rolls[1]).endIndex]))
                    expectedRoll += modifier.expressionValue(with: nil, context: nil) as! Double
                }
                avgResult += expectedRoll
            default:
                print("Syntax error. Could not parse \(roll): Split resulted in  \(rolls.count) fragments, but 2 were expected: (1) number of rolls and (2) die size + or - modifier. Specifically, the letter d should appear only once (between the two).")
                return -99.0
        }
    }
    return avgResult
}

/* * *
*   A roll that represents a flat check, skill check, ability check, saving throw or attack roll.
*   It contains a modifier and is tested against a DC. It will be treated as a success if it meets or exceeds the DC, as a critical success if
*   it meets or exceeds 10+DC and as a failure otherwise (critical failures are not calculated at the moment).
*   A natural 1 will be treated as 1 degree worse than it would numerically be (if this makes a difference) and conversely a natural 20 as 1 degree better.
* * */
 struct checkRoll {
	var modifier = 13
	var DC = 10
	func getProbToHit() -> Double {
		let requiredRoll = DC-modifier
		switch (requiredRoll) {
			case .min ... -9: return 1.0	// A natural 1 would numerically be a critical success and thus still be treated as a success.
			case -8 ... 1: return 0.95		// Anything would numerically be a success but since a natural 1 would only be a normal success, it is treated as a failure.
			case 20 ... 30: return 0.05		// Anything would numerically fail, but a natural 20 would only be a normal failure and is thus treated as a success.
			case 31 ... .max: return 0.0	// Even a natural 20 would numerically be a critical failure and thus still fail if it is treated one degree better.
			default: return (1.05-((Double)(requiredRoll)/20.0))
		}
	}
	func getProbToCrit() -> Double {
		let requiredRoll = 10+DC-modifier
		switch (requiredRoll) {
			case .min ... 1: return 0.95	// Anything would numerically be a crit success, but a natural 1 still gets demoted to a normal success.
			case 20 ... 30: return 0.05		// A natural 20 would numerically be a normal success and thus be promoted to a crit.
			case 31 ... .max: return 0.0	// Even a natural 20 wouldn't numerically be a success.
			default: return (1.05-((Double)(requiredRoll)/20.0))
		}
	}
	// Conveniance function for when we want to treat critical and non-critical hits seperately
	func getProbToNormalHit() -> Double {
		return getProbToHit() - getProbToCrit()
	}
}

/* * *
*   Attack rolls contain
*	- attackBonus: An Array of all applicable attack bonusses (including MAP)
*	- normalDmg: The average damage of a non-critical hit (may be calculated via parseDice())
*	- critDmg: The average damage of a critical hit (may be calculated via parseDice())
* * */
struct attackRolls {
	var attackBonus = [0]
	var normalDmg = 0.0
	var critDmg = 0.0
}

struct opponent {
	var description: String
	var CRAdjust: Int
}

func main() {
    
    /* default data block in case we find no valid JSON file.*/
    var outputBeginning = "Average Damage: "
    var level = 2
    var attacks = [
        attackRolls(
            attackBonus: [8, 5, 2],
            normalDmg: parseDice(rollArray: ["1d8-1"]),
            critDmg: parseDice(rollArray: ["2d8-2", "1d10"])),
        attackRolls(
            attackBonus: [7, 4],
            normalDmg: parseDice(rollArray: ["1d6+3"]),
            critDmg: parseDice(rollArray: ["2d6+6"]))
        ]
    var jsonURLs: [URL] = []

    if (CommandLine.arguments.count > 1) {
        for i in 1..<CommandLine.arguments.count {
            jsonURLs.append(NSURL(fileURLWithPath: CommandLine.arguments[i]) as URL)
        }
    } else {
        print ("Note: You can specify one or more JSON files as input as an argument to this script. Trying ./PC.json as a default..")
        jsonURLs.append(NSURL(fileURLWithPath: "PC.json") as URL)
    }
    for jsonURL in jsonURLs {
        do {
            let data = try Data(contentsOf: jsonURL, options: .mappedIfSafe)
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let jsonResult = jsonResult as? Dictionary<String, AnyObject> {
                if let PCname = jsonResult["name"] as? String {
                    outputBeginning = "\(PCname) does an average damage of "
                }
                if let PClevel = jsonResult["level"] as? Int {
                    level = PClevel
                }
                if let attackArr = jsonResult["attacks"] as? [Any] {
                    attacks = []
                    for attack in attackArr {
                        if let thisAttack = attack as? Dictionary<String, AnyObject> {
                            var thisAttackBonusses: [Int]
                            var thisNormalDmg: Double
                            var thisCritDmg: Double
                            if let normalDmgRolls = thisAttack["normalDmg"] as? [String] {
                                thisNormalDmg = parseDice(rollArray: normalDmgRolls)
                                if let thisAttackRolls = thisAttack["attackRolls"] as? [Int] {
                                    thisAttackBonusses = thisAttackRolls
                                    if let CritDmgRolls = thisAttack["critDmg"] as? [String] {
                                        thisCritDmg = parseDice(rollArray: CritDmgRolls)
                                    } else {
                                        thisCritDmg = 2.0 * thisNormalDmg
                                    }
                                    attacks.append(attackRolls(
                                        attackBonus: thisAttackBonusses,
                                        normalDmg: thisNormalDmg,
                                        critDmg: thisCritDmg
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        } catch let e {
               print("Could not parse PC.json: \(e)\n. Continuing with default data.")
        }
    	let opponents = [opponent(description: "Lackeys", CRAdjust: -2), opponent(description: "Normal Foes", CRAdjust: 0), opponent(description: "Bosses", CRAdjust: 2)]

    	for foe in opponents {
    		var chk = checkRoll(modifier: 0, DC: getACforCR(CR: level+foe.CRAdjust))
    		var avgDmg=0.0
    		for attack in attacks {
    			for bonus in attack.attackBonus {
    				chk.modifier = bonus
    				avgDmg += chk.getProbToNormalHit() * attack.normalDmg + chk.getProbToCrit() * attack.critDmg
    			}
    		}
            
    		print("\(outputBeginning)\((Double)((Int)(avgDmg*1000))/1000) against \(foe.description) (AC \(chk.DC))")
    	}
    }
}
