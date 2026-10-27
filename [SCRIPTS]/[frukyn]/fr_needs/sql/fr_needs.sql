UPDATE `ox_statuses` SET `default` = 15, `onTick` = 0.02 WHERE `name` = 'hunger';
UPDATE `ox_statuses` SET `default` = 15, `onTick` = 0.05 WHERE `name` = 'thirst';
UPDATE `ox_statuses` SET `default` = 15, `onTick` = -0.10 WHERE `name` = 'stress';

INSERT INTO `ox_statuses` (`name`, `default`, `onTick`)
SELECT 'hunger', 15, 0.02
WHERE NOT EXISTS (SELECT 1 FROM `ox_statuses` WHERE `name` = 'hunger');

INSERT INTO `ox_statuses` (`name`, `default`, `onTick`)
SELECT 'thirst', 15, 0.05
WHERE NOT EXISTS (SELECT 1 FROM `ox_statuses` WHERE `name` = 'thirst');

INSERT INTO `ox_statuses` (`name`, `default`, `onTick`)
SELECT 'stress', 15, -0.10
WHERE NOT EXISTS (SELECT 1 FROM `ox_statuses` WHERE `name` = 'stress');

INSERT INTO `ox_statuses` (`name`, `default`, `onTick`)
SELECT 'alcohol', 0, -0.02
WHERE NOT EXISTS (SELECT 1 FROM `ox_statuses` WHERE `name` = 'alcohol');

INSERT INTO `ox_statuses` (`name`, `default`, `onTick`)
SELECT 'drug', 0, -0.02
WHERE NOT EXISTS (SELECT 1 FROM `ox_statuses` WHERE `name` = 'drug');
