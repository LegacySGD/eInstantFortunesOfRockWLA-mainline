<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario             = getScenario(jsonContext);
						var scenarioGridQty      = getGridQty(scenario);
						var scenarioGridsData    = getGridsData(scenario,scenarioGridQty);
						var scenarioMatchBonus   = getMatchBonus(scenario,scenarioGridQty);
						var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function(item) {return item.replace(/\t|\r|\n/gm, "")} );
						var prizeNames           = (prizeNamesDesc.substring(1)).split(',');

						////////////////////
						// Parse scenario //
						////////////////////

						const gridCols = 5;
						const gridRows = 3;

						var arrGridData  = [];
						var arrAuditData = [];
						var gridsData    = [];

						function getPhasesData(A_arrGridData, A_arrAuditData)
						{
							var arrClusters   = [];
							var arrPhaseCells = [];
							var arrPhases     = [];
							var objCluster    = {};
							var objPhase      = {};

							if (A_arrAuditData != '')
							{
								for (var phaseIndex = 0; phaseIndex < A_arrAuditData.length; phaseIndex++)
								{
									objPhase = {arrGrid: [], arrClusters: []};

									for (var colIndex = 0; colIndex < gridCols; colIndex++)
									{
										objPhase.arrGrid.push(A_arrGridData[colIndex].substr(0,gridRows));
									}

									arrClusters   = A_arrAuditData[phaseIndex].split(":");
									arrPhaseCells = [];

									for (var clusterIndex = 0; clusterIndex < arrClusters.length; clusterIndex++)
									{
										objCluster = {strPrefix: '', arrCells: []};

										objCluster.strPrefix = arrClusters[clusterIndex][0];

										objCluster.arrCells = arrClusters[clusterIndex].slice(1).match(new RegExp('.{1,2}', 'g')).map(function(item) {return parseInt(item,10);} );

										objPhase.arrClusters.push(objCluster);

										arrPhaseCells = arrPhaseCells.concat(objCluster.arrCells);
									}

									arrPhases.push(objPhase);

									arrPhaseCells.sort(function(a,b) {return b-a;} );

									for (var cellIndex = 0; cellIndex < arrPhaseCells.length; cellIndex++)
									{
										if (cellIndex == 0 || (cellIndex > 0 && arrPhaseCells[cellIndex] != arrPhaseCells[cellIndex-1]))
										{
											cellCol = Math.floor((arrPhaseCells[cellIndex]-1) / gridRows);
											cellRow = (arrPhaseCells[cellIndex]-1) % gridRows;

											if (cellCol >= 0 && cellCol < gridCols)
											{			
												A_arrGridData[cellCol] = A_arrGridData[cellCol].substring(0,cellRow) + A_arrGridData[cellCol].substring(cellRow+1);
											}
										}
									}
								}
							}

							objPhase = {arrGrid: [], arrClusters: []};

							for (var colIndex = 0; colIndex < gridCols; colIndex++)
							{
								objPhase.arrGrid.push(A_arrGridData[colIndex].substr(0,gridRows));
							}

							arrPhases.push(objPhase);

							return arrPhases;
						}

						for (var gridIndex = 0; gridIndex < scenarioGridQty; gridIndex++)
						{
							arrGridData  = scenarioGridsData[gridIndex].split(':')[0].split(',');
							arrAuditData = scenarioGridsData[gridIndex].split(':').slice(1).join(':').split(',');

							gridsData.push(getPhasesData(arrGridData, arrAuditData));
						}

						/////////////////////////
						// Currency formatting //
						/////////////////////////

						var bCurrSymbAtFront = false;
						var strCurrSymb      = '';
						var strDecSymb       = '';
						var strThouSymb      = '';

						function getCurrencyInfoFromTopPrize()
						{
							var topPrize               = convertedPrizeValues[0];
							var strPrizeAsDigits       = topPrize.replace(new RegExp('[^0-9]', 'g'), '');
							var iPosFirstDigit         = topPrize.indexOf(strPrizeAsDigits[0]);
							var iPosLastDigit          = topPrize.lastIndexOf(strPrizeAsDigits.substr(-1));
							bCurrSymbAtFront           = (iPosFirstDigit != 0);
							strCurrSymb 	           = (bCurrSymbAtFront) ? topPrize.substr(0,iPosFirstDigit) : topPrize.substr(iPosLastDigit+1);
							var strPrizeNoCurrency     = topPrize.replace(new RegExp('[' + strCurrSymb + ']', ''), '');
							var strPrizeNoDigitsOrCurr = strPrizeNoCurrency.replace(new RegExp('[0-9]', 'g'), '');
							strDecSymb                 = strPrizeNoDigitsOrCurr.substr(-1);
							strThouSymb                = (strPrizeNoDigitsOrCurr.length > 1) ? strPrizeNoDigitsOrCurr[0] : strThouSymb;
						}

						function getPrizeInCents(AA_strPrize)
						{
							return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
						}

						function getCentsInCurr(AA_iPrize)
						{
							var strValue = AA_iPrize.toString();

							strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
							strValue = strValue.substr(0,strValue.length-2) + strDecSymb + strValue.substr(-2);
							strValue = (strValue.length > 6) ? strValue.substr(0,strValue.length-6) + strThouSymb + strValue.substr(-6) : strValue;
							strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

							return strValue;
						}

						getCurrencyInfoFromTopPrize();

						///////////////////////
						// Output Game Parts //
						///////////////////////

						const cellSize   = 24;
						const cellMargin = 1;
						const cellTextX  = 13;
						const cellTextY  = 15;

						const colourBlack   = '#000000';
						const colourBlue    = '#99ccff';
						const colourCyan    = '#ccffff';
						const colourGreen   = '#99ff99';
						const colourLemon   = '#ffff99';
						const colourLilac   = '#ccccff';
						const colourLime    = '#ccff99';
						const colourNavy    = '#0000ff';
						const colourOrange  = '#ffcc99';
						const colourPink    = '#ffcccc';
						const colourPurple  = '#cc99ff';
						const colourRed     = '#ff9999';
						const colourScarlet = '#ff0000';
						const colourWhite   = '#ffffff';
						const colourYellow  = '#ffff00';

						const symbPrizes     = 'ABCDEFG';
						const symbWild       = 'W';
						const symbFreePlay   = 'P';
						const symbMatchBonus = 'Q';
						const symbSpecials   = symbWild + symbFreePlay + symbMatchBonus;
						const symbBonus     = 'ABCDEFGHIJ';

						const prizeColours       = [colourRed, colourOrange, colourLemon, colourLime, colourBlue, colourLilac, colourPurple];
						const specialBoxColours  = [colourBlack, colourScarlet, colourNavy];
						const specialTextColours = [colourWhite, colourYellow, colourYellow];
						const bonusColours       = [colourRed, colourOrange, colourLemon, colourLime, colourGreen, colourCyan, colourBlue, colourLilac, colourPurple, colourPink];

						var boxColourStr  = '';
						var canvasIdStr   = '';
						var elementStr    = '';
						var strCellText   = '';
						var textColourStr = '';

						var doTrigger        = false;
						var gridCanvasHeight = gridRows * cellSize + 2 * cellMargin;
						var gridCanvasWidth  = gridCols * cellSize + 2 * cellMargin;

						var r = [];

						function showBox(A_strCanvasId, A_strCanvasElement, A_iBoxWidth, A_strBoxColour, A_strTextColour, A_strText)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var canvasWidth  = A_iBoxWidth + 2 * cellMargin;
							var canvasHeight = cellSize + 2 * cellMargin;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + canvasWidth.toString() + '" height="' + canvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold 14px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + A_iBoxWidth.toString() + ', ' + cellSize.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (A_iBoxWidth - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + (A_iBoxWidth / 2 + cellMargin).toString() + ', ' + cellTextY.toString() + ');');

							r.push('</script>');
						}

						function showGrid(A_strCanvasId, A_strCanvasElement, A_arrGrid)
						{
							var canvasCtxStr     = 'canvasContext' + A_strCanvasElement;
							var cellX            = 0;
							var cellY            = 0;
							var isPrizeCell      = false;
							var symbCell         = '';
							var symbIndex        = -1;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + gridCanvasWidth.toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');

							for (var gridCol = 0; gridCol < gridCols; gridCol++)
							{
								for (var gridRow = 0; gridRow < gridRows; gridRow++)
								{
									symbCell      = A_arrGrid[gridCol][gridRow];
									isPrizeCell   = (symbPrizes.indexOf(symbCell) != -1);
									symbIndex     = (isPrizeCell) ? symbPrizes.indexOf(symbCell) : symbSpecials.indexOf(symbCell);
									boxColourStr  = (isPrizeCell) ? prizeColours[symbIndex] : specialBoxColours[symbIndex];
									textColourStr = (isPrizeCell) ? colourBlack : specialTextColours[symbIndex];
									cellX         = gridCol * cellSize;
									cellY         = (gridRows - gridRow - 1) * cellSize;

									r.push(canvasCtxStr + '.font = "bold 14px Arial";');
									r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
									r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
									r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + cellTextX).toString() + ', ' + (cellY + cellTextY).toString() + ');');
								}
							}

							r.push('</script>');
						}

						function showAudit(A_strCanvasId, A_strCanvasElement, A_arrGrid, A_arrData)
						{
							var canvasCtxStr  = 'canvasContext' + A_strCanvasElement;
							var cellNum       = 0;
							var cellX         = 0;
							var cellY         = 0;
							var isClusterCell = false;
							var isPrizeCell   = false;
							var isSpecialCell = false;
							var isWildCell    = false;
							var symbCell      = '';
							var symbIndex     = -1;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + (gridCanvasWidth + 25).toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');

							for (var gridCol = 0; gridCol < gridCols; gridCol++)
							{
								for (var gridRow = 0; gridRow < gridRows; gridRow++)
								{
									cellNum++;

									isClusterCell = (A_arrData.arrCells.indexOf(cellNum) != -1);
									isWildCell    = (isClusterCell && A_arrGrid[gridCol][gridRow] == symbWild);
									symbCell      = ('0' + cellNum).slice(-2);
									isSpecialCell = (isWildCell || (isClusterCell && symbSpecials.indexOf(A_arrData.strPrefix) != -1));
									isPrizeCell   = (!isSpecialCell && isClusterCell && symbPrizes.indexOf(A_arrData.strPrefix) != -1);
									symbIndex     = (isPrizeCell) ? symbPrizes.indexOf(A_arrData.strPrefix) : ((isSpecialCell) ? ((isWildCell) ? symbSpecials.indexOf(symbWild) : symbSpecials.indexOf(A_arrData.strPrefix)) : -1);
									boxColourStr  = (isPrizeCell) ? prizeColours[symbIndex] : ((isSpecialCell) ? specialBoxColours[symbIndex] : colourWhite);									
									textColourStr = (isPrizeCell) ? colourBlack : ((isSpecialCell) ? specialTextColours[symbIndex] : colourBlack);
									cellX         = gridCol * cellSize;
									cellY         = (gridRows - gridRow - 1) * cellSize;

									r.push(canvasCtxStr + '.font = "bold 14px Arial";');
									r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
									r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
									r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + cellTextX).toString() + ', ' + (cellY + cellTextY).toString() + ');');
								}
							}

							r.push('</script>');
						}

						///////////////////////
						// Prize Symbols Key //
						///////////////////////

						r.push('<div style="float:left; margin-right:50px">');
						r.push('<p>' + getTranslationByName("titlePrizeSymbolsKey", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var prizeIndex = 0; prizeIndex < symbPrizes.length; prizeIndex++)
						{
							symbPrize    = symbPrizes[prizeIndex];
							canvasIdStr  = 'cvsKeySymb' + symbPrize;
							elementStr   = 'eleKeySymb' + symbPrize;
							boxColourStr = prizeColours[prizeIndex];
							symbDesc     = 'symb' + symbPrize;

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showBox(canvasIdStr, elementStr, cellSize, boxColourStr, colourBlack, symbPrize);

							r.push('</td>');
							r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						/////////////////////////
						// Special Symbols Key //
						/////////////////////////

						r.push('<div style="float:left">');
						r.push('<p>' + getTranslationByName("titleSpecialSymbolsKey", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var specialIndex = 0; specialIndex < symbSpecials.length; specialIndex++)
						{
							symbSpecial   = symbSpecials[specialIndex];
							canvasIdStr   = 'cvsKeySymb' + symbSpecial;
							elementStr    = 'eleKeySymb' + symbSpecial;
							boxColourStr  = specialBoxColours[specialIndex];
							textColourStr = specialTextColours[specialIndex];
							symbDesc      = 'symb' + symbSpecial;

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showBox(canvasIdStr, elementStr, cellSize, boxColourStr, textColourStr, symbSpecial);

							r.push('</td>');
							r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						//////////////////////////////
						// Main Game and Free Plays //
						//////////////////////////////

						const qtyFPTrigger = 3;
						const qtyMBTrigger = 3;

						var collectedText = '';
						var countText     = '';
						var isCluster     = false;
						var isFPSymb      = false;
						var isMBSymb      = false;
						var maxClusters   = 0;
						var phaseStr      = '';
						var prefixIndex   = -1;
						var prizeCount    = 0;
						var prizeStr      = '';
						var prizeText     = '';
						var qtyFPSymbs    = 0;
						var qtyMBSymbs    = 0;
						var titleStr      = '';
						var triggerText   = '';

						for (var gridIndex = 0; gridIndex < scenarioGridQty; gridIndex++)
						{
							for (var phaseIndex = 0; phaseIndex < gridsData[gridIndex].length; phaseIndex++)
							{
								if (gridsData[gridIndex][phaseIndex].arrClusters.length > maxClusters)
								{
									maxClusters = gridsData[gridIndex][phaseIndex].arrClusters.length;
								}
							}
						}

						for (var gridIndex = 0; gridIndex < scenarioGridQty; gridIndex++)
						{
							if (gridIndex < 2)
							{
								titleStr = (gridIndex == 0) ? 'mainGame' : 'symbP';

								r.push('<p style="clear:both"><br>' + getTranslationByName(titleStr, translations).toUpperCase() + '</p>');
							}

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');						

							for (var phaseIndex = 0; phaseIndex < gridsData[gridIndex].length; phaseIndex++)
							{
								r.push('<tr class="tablebody">');

								////////////////
								// Phase Info //
								////////////////

								phaseStr  = (gridIndex > 0 && phaseIndex == 0) ? getTranslationByName("symbP", translations) + ' ' + gridIndex.toString() + '<br><br>' : '';
								phaseStr += getTranslationByName("phaseNum", translations) + ' ' + (phaseIndex+1).toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + gridsData[gridIndex].length.toString();

								r.push('<td valign="top">' + phaseStr + '</td>');

								///////////////
								// Game Grid //
								///////////////

								canvasIdStr = 'cvsGrid' + gridIndex.toString() + '_' + phaseIndex.toString();
								elementStr  = 'eleGrid' + gridIndex.toString() + '_' + phaseIndex.toString();

								r.push('<td valign="top" style="padding-left:50px; padding-right:50px; padding-bottom:25px">');

								showGrid(canvasIdStr, elementStr, gridsData[gridIndex][phaseIndex].arrGrid);

								r.push('</td>');

								//////////////
								// Clusters //
								//////////////

								r.push('<td valign="top" style="padding-right:50px; padding-bottom:25px">');

								for (clusterIndex = 0; clusterIndex < gridsData[gridIndex][phaseIndex].arrClusters.length; clusterIndex++)
								{
									canvasIdStr = 'cvsAudit' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();
									elementStr  = 'eleAudit' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();

									showAudit(canvasIdStr, elementStr, gridsData[gridIndex][phaseIndex].arrGrid, gridsData[gridIndex][phaseIndex].arrClusters[clusterIndex]);
								}

								for (clusterIndex = gridsData[gridIndex][phaseIndex].arrClusters.length; clusterIndex < maxClusters; clusterIndex++)
								{
									canvasIdStr = 'cvsAudit' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();

									r.push('<canvas id="' + canvasIdStr + '" width="' + (gridCanvasWidth + 25).toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
								}

								r.push('</td>');

								////////////
								// Prizes //
								////////////

								r.push('<td valign="top" style="padding-bottom:25px">');

								if (gridsData[gridIndex][phaseIndex].arrClusters.length > 0)
								{
									r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

									for (var clusterIndex = 0; clusterIndex < gridsData[gridIndex][phaseIndex].arrClusters.length; clusterIndex++)
									{
										symbPrize     = gridsData[gridIndex][phaseIndex].arrClusters[clusterIndex].strPrefix;
										isCluster     = (symbPrizes.indexOf(symbPrize) != -1);
										isFPSymb      = (symbPrize == symbFreePlay);
										isMBSymb      = (symbPrize == symbMatchBonus);
										canvasIdStr   = 'cvsPrize' + phaseIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
										elementStr    = 'elePrize' + phaseIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
										prefixIndex   = (isCluster) ? symbPrizes.indexOf(symbPrize) : ((isFPSymb || isMBSymb) ? symbSpecials.indexOf(symbPrize) : -1);
										boxColourStr  = (isCluster) ? prizeColours[prefixIndex] : ((isFPSymb || isMBSymb) ? specialBoxColours[prefixIndex] : colourWhite);
										textColourStr = (isCluster) ? colourBlack : ((isFPSymb || isMBSymb) ? specialTextColours[prefixIndex] : colourWhite);
										prizeCount    = gridsData[gridIndex][phaseIndex].arrClusters[clusterIndex].arrCells.length;
										prizeText     = symbPrize + prizeCount.toString();									

										if (isFPSymb)
										{
											qtyFPSymbs   += prizeCount;
											collectedText = getTranslationByName("collected", translations) + ' ' + qtyFPSymbs.toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + qtyFPTrigger.toString();
											triggerText   = (qtyFPSymbs == qtyFPTrigger) ? ' : ' + getTranslationByName("symbP", translations) + ' ' + getTranslationByName("bonusTriggered", translations) : '';
										}

										if (isMBSymb)
										{
											qtyMBSymbs   += prizeCount;
											collectedText = getTranslationByName("collected", translations) + ' ' + qtyMBSymbs.toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + qtyMBTrigger.toString();
											triggerText   = (qtyMBSymbs == qtyMBTrigger) ? ' : ' + getTranslationByName("symbQ", translations) + ' ' + getTranslationByName("bonusTriggered", translations) : '';
										}

										countText = (isCluster || isFPSymb || isMBSymb) ? prizeCount.toString() + ' x' : '';
										prizeStr  = (isCluster) ? '= ' + convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)] : ((isFPSymb || isMBSymb) ? collectedText + triggerText : '');

										r.push('<tr class="tablebody">');
										r.push('<td align="right">' + countText + '</td>');
										r.push('<td align="center">');

										showBox(canvasIdStr, elementStr, cellSize, boxColourStr, textColourStr, symbPrize);
										
										r.push('</td>');
										r.push('<td>' + prizeStr + '</td>');
										r.push('</tr>');
									}

									r.push('</table>');
								}

								r.push('</td>');
								r.push('</tr>');
							}

							r.push('</table>');
						}

						////////////////////////
						// Symbol Match Bonus //
						////////////////////////

						if (qtyMBSymbs == qtyMBTrigger && scenarioMatchBonus != '')
						{
							const bonusMultis = [1,2,3,5,10];
							const roundsQty   = 5;
							const chanceQty   = 3;

							var chanceMultiIndex = [0,0,0];
							var chanceStr        = '';
							var chanceSymb       = '';
							var chanceTarget     = '';
							var arrChances       = [];
							var multiStr         = '';
							var multiVal         = 0;
							var prizeVal         = 0;
							var roundStr         = '';
							var symbIndex        = -1;

							r.push('<p>' + getTranslationByName("titleSymbolMatch", translations).toUpperCase() + '</p>');

							///////////////////////
							// Bonus Symbols Key //
							///////////////////////

							r.push('<div style="float:left; margin-right:50px">');
							r.push('<p>' + getTranslationByName("titleMatchSymbolsKey", translations) + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablehead">');
							r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
							r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
							r.push('</tr>');

							for (var prizeIndex = 0; prizeIndex < symbBonus.length; prizeIndex++)
							{
								symbPrize    = symbBonus[prizeIndex];
								canvasIdStr  = 'cvsKeyBonus' + symbPrize;
								elementStr   = 'eleKeyBonus' + symbPrize;
								boxColourStr = bonusColours[prizeIndex];
								symbDesc     = 'symbB' + symbPrize;

								r.push('<tr class="tablebody">');
								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, cellSize, boxColourStr, colourBlack, symbPrize);

								r.push('</td>');
								r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
								r.push('</tr>');
							}

							r.push('</table>');
							r.push('</div>');

							r.push('<p style="clear:both"><br>' + getTranslationByName("titleBonusRounds", translations).toUpperCase() + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

							for (var roundIndex = 0; roundIndex < roundsQty; roundIndex++)
							{
								arrChances = scenarioMatchBonus[roundIndex].split(':');

								r.push('<tr class="tablebody">');

								////////////////
								// Round Info //
								////////////////

								roundStr = getTranslationByName("roundNum", translations) + ' ' + (roundIndex+1).toString() + ' ' + getTranslationByName("roundOf", translations) + ' ' + roundsQty.toString();

								r.push('<td valign="top">' + roundStr + '</td>');

								r.push('<td style="padding-left:50px; padding-right:50px; padding-bottom:25px">');
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablehead">');
								r.push('<td>&nbsp;</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusTarget", translations) + '</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusSymbol", translations) + '</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusMulti", translations) + '</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusWins", translations) + '</td>');
								r.push('</tr>');

								for (var chanceIndex = 0; chanceIndex < chanceQty; chanceIndex++)
								{
									r.push('<tr class="tablebody">');

									/////////////////
									// Chance Info //
									/////////////////

									chanceStr = getTranslationByName("chanceNum", translations) + ' ' + (chanceIndex+1).toString() + ' ' + getTranslationByName("chanceOf", translations) + ' ' + chanceQty.toString();

									r.push('<td>' + chanceStr + '</td>');

									////////////
									// Target //
									////////////

									chanceTarget = arrChances[chanceIndex][0];
									canvasIdStr  = 'cvsBonusTarget' + roundIndex.toString() + '_' + chanceIndex.toString();
									elementStr   = 'eleBonusTarget' + roundIndex.toString() + '_' + chanceIndex.toString();
									symbIndex    = symbBonus.indexOf(chanceTarget);
									boxColourStr = bonusColours[symbIndex];

									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, cellSize, boxColourStr, colourBlack, chanceTarget);

									r.push('</td>');

									////////////
									// Symbol //
									////////////

									chanceSymb   = arrChances[chanceIndex][1];
									canvasIdStr  = 'cvsBonusSymb' + roundIndex.toString() + '_' + chanceIndex.toString();
									elementStr   = 'eleBonusSymb' + roundIndex.toString() + '_' + chanceIndex.toString();
									symbIndex    = symbBonus.indexOf(chanceSymb);
									boxColourStr = bonusColours[symbIndex];

									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, cellSize, boxColourStr, colourBlack, chanceSymb);

									r.push('</td>');

									////////////////
									// Multiplier //
									////////////////

									multiVal = bonusMultis[chanceMultiIndex[chanceIndex]];
									multiStr = 'x' + multiVal.toString();

									r.push('<td align="center">' + multiStr + '</td>');

									//////////
									// Wins //
									//////////

									r.push('<td align="center">');

									if (chanceTarget == chanceSymb)
									{
										countText    = multiVal.toString() + ' x';
										canvasIdStr  = 'cvsBonusWin' + roundIndex.toString() + '_' + chanceIndex.toString();
										elementStr   = 'eleBonusWin' + roundIndex.toString() + '_' + chanceIndex.toString();
										symbIndex    = symbBonus.indexOf(chanceTarget);
										boxColourStr = bonusColours[symbIndex];
										prizeStr     = convertedPrizeValues[getPrizeNameIndex(prizeNames, 'B' + chanceTarget)];
										prizeVal     = getPrizeInCents(prizeStr) * multiVal;
										prizeStr     = getCentsInCurr(prizeVal);

										r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
										r.push('<tr class="tablebody">');
										r.push('<td align="right">' + countText + '</td>');
										r.push('<td align="center">');

										showBox(canvasIdStr, elementStr, cellSize, boxColourStr, colourBlack, chanceTarget);
										
										r.push('</td>');
										r.push('<td>' + prizeStr + '</td>');
										r.push('</tr>');
										r.push('</table>');

										chanceMultiIndex[chanceIndex]++;
									}

									r.push('</td>');
									r.push('</tr>');
								}

								r.push('</table>');
								r.push('</td>');
								r.push('</tr>');
							}

							r.push('</table>');
						}

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// DEBUG OUTPUT TABLE
						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						if (debugFlag)
						{
							//////////////////////////////////////
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for (var idx = 0; idx < debugFeed.length; idx++)
 							{
								if (debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}

						return r.join('');
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");
						
						for (var i = 0; i < pricePoints.length; ++i)
						{
							if (wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}
						
						return "";
					}

					// Input: Json document string containing 'scenario' at root level.
					// Output: Scenario value.
					function getScenario(jsonContext)
					{
						// Parse json and retrieve scenario string.
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						// Trim null from scenario string.
						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}

					function getGridQty(scenario)
					{
						return parseInt(scenario.split('|')[0], 10);
					}

					function getGridsData(scenario,gridQty)
					{
						return scenario.split('|').slice(1,gridQty+1);
					}

					function getMatchBonus(scenario,gridQty)
					{
						return scenario.split('|')[gridQty+1].split(',');
					}
					
					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; i++)
						{
							if (prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}
					/////////////////////////////////////////////////////////////////////////////////////////

					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if (childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								//registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
