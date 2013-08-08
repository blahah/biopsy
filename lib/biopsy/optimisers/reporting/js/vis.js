////////////////////////
//// Data loading   ////
////////////////////////

var optimiser = "tabu_search";

var names = {
  'n50': 'n50',
  'longest contig': 'largest',
  'reads mapped': 'brm_paired',
  'conditional annotations': 'rba_result'
};

function setObjective(o) {
  objective = names[o];
  loadDataForObjective(objective);
}

function clearPlots() {
  d3.selectAll("svg").remove();
}

function loadVisualisation() {
  createSvgs();
  setupPlots();
  setObjective('n50');
}

$(".dropdown-menu li a").click(function(){
  var selText = $(this).text();
  $(this).parents('.btn-group').find('.dropdown-toggle').html(selText+' <span class="caret"></span>');
  setObjective(selText);
});

////////////////////////
//// Plot settings  ////
////////////////////////

// main plot
var margin = {top: 10, right: 20, bottom: 20, left: 40},
  width = 740 - margin.left - margin.right,
  height = 400 - margin.top - margin.bottom;

var x = d3.scale.linear()
  .range([0, width]);

var y = d3.scale.linear()
  .range([height, 0]);

var xAxis = d3.svg.axis()
  .scale(x)
  .orient("bottom");

var yAxis = d3.svg.axis()
  .scale(y)
  .orient("left");

var mainsvg = null;

function createMainSvg() {
  mainsvg = d3.select("#main").append("svg")
              .attr("width", width + margin.left + margin.right)
              .attr("height", height + margin.top + margin.bottom)
            .append("g")
              .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
}

// top plot
var tmargin = {top: 10, right: 20, bottom: 5, left: 40},
  twidth = 740 - tmargin.left - tmargin.right,
  theight = 50 - tmargin.top - tmargin.bottom;

var ty = d3.scale.linear()
  .range([theight, 0]);

var tyAxis = d3.svg.axis()
  .scale(ty)
  .ticks(2)
  .orient("left");

var topsvg = null;

function createTopSvg() {
  topsvg = d3.select("#top-main").append("svg")
                .attr("width", twidth + tmargin.left + tmargin.right)
                .attr("height", theight + tmargin.top + tmargin.bottom)
              .append("g")
                .attr("transform", "translate(" + tmargin.left + "," + tmargin.top + ")");
}

// left plot
var lmargin = {top: 10, right: 3, bottom: 20, left: 5},
  lwidth = 70 - lmargin.left - lmargin.right,
  lheight = 400 - lmargin.top - lmargin.bottom;

var lx = d3.scale.linear()
  .range([lwidth, 0]);

var lxAxis = d3.svg.axis()
  .scale(lx)
  .ticks(1)
  .orient("bottom");

var leftsvg = null;

function createLeftSvg() {
  leftsvg = d3.select("#left").append("svg")
                .attr("width", lwidth + lmargin.left + lmargin.right)
                .attr("height", lheight + lmargin.top + lmargin.bottom)
              .append("g")
                .attr("transform", "translate(" + lmargin.left + "," + lmargin.top + ")");
}

function createSvgs() {
  createMainSvg();
  createTopSvg();
  createLeftSvg();
}

////////////////////////
//// Plot helpers   ////
////////////////////////

// generic helpers
var colour = d3.scale.category20();

var round = Math.round;

// line generator
var line = d3.svg.line()
  .x(function(d) { return x(d.iterid); })
  .y(function(d) { return y(d.score); });

// line highlighting
var highlighted = null;

// highlight a path until the next one is selected
function highlightPath(t) {
  if (highlighted !== null) {
    unHighlightPath(highlighted);
  }
  t.transition()
    .duration(50)
    .style("stroke-opacity", 1.0)
    .style("stroke", 'black');
  highlighted = t;
}

// remove highlighting from path
function unHighlightPath(t) {
  t.transition()
    .duration(50)
    .style("stroke-opacity", 0.1)
    .style("stroke", 'forestgreen');
}

// a formatter for counts.
var formatCount = d3.format(",.0f");
var format = d3.format("d");

///////////////////////////////////////
//// Load data and generate plots  ////
///////////////////////////////////////

var distributions;
function loadAllData() {
  // left data file & plot generation
  d3.csv("data/first_set.csv", function(error, data) {
    distributions = {
      'n50': [],
      'time': [],
      'largest': [],
      'brm_paired': [],
      'rba_result': []
    };
    data.forEach(function(d) {
      distributions['n50'].push(d.n50);
      distributions['time'].push(d.time);
      distributions['largest'].push(d.largest);
      distributions['brm_paired'].push(d.brm_paired);
      distributions['rba_result'].push(d.rba_result);
    });

    loadVisualisation();
  });
}

var objectivedata = {};
function loadDataForObjective(objective) {

  // have we cached the data already?
  if (objective in objectivedata) {
    console.log('already got stored data');
    updatePlotsForObjective(objective);
    return;
  }

  // load from file
  d3.csv("data/" + objective + ".csv", function(error, data) {

    var runs = [];
    var topdata = [];

    // numericise variables and store the runids
    data.forEach(function(d) {
      d.runid = round(d.runid);
      d.iterid = round(d.iterid);
      d.hood_no = round(d.hood_no);
      d.score = round(d.score);

      runs.push(d.runid);
    });

    var d2 = {};

    // convert run number to a name
    var runname = function(d) {
      return 'run' + d;
    };

    // unique list
    runs = d3.keys(d3.set(runs));

    // store each run under its name
    // todo: could this be done with d3.nest? 
    for (var i in runs) {
      d2[runname(runs[i])] = data.filter(function(d) { return d.runid == round(i)+1; });
    }

    // in case we want to colour by runs
    colour.domain(d3.keys(d2));

    // restructure the data so we have an array of
    // objects, one per iteration per run
    // todo: could this be done with d3.nest too?
    runs = colour.domain().map(function(name) {
      var scores = d2[name].map(function(d) {
        return round(d.score);
      });
      return {
        name: name, // runid
        max: d3.max(scores), // highest score reached
        n: scores.length, // total number of iterations
        levels: scores.filter(function(v,i) {
          return i==scores.lastIndexOf(v);
        }).length, // number of different 'best' scores explored
        values: d2[name].map(function(d) {
          return { iterid: round(d.iterid), score: round(d.score) };
        }), // the parameters and score for each iterid
        params: d2[name].slice(scores.length - 1).map(function(d) {
            topdata.push(d.iterid);
            return 'K: ' + d.K + ', M:' + d.M + ', d:' + d.d + ', D:' + d.D + ', e:' + d.e + ', t:' + d.t;
        }) // the parameters used for the best score
      };
    });

    // store extent data for scaling
    iterid_extent = d3.extent(data, function(d) { return round(d.iterid); });
    score_extent = d3.extent(data, function(d) { return round(d.score); });

    objectivedata[objective] = {
      'runs': runs,
      'topdata': topdata,
      'iterid_extent': iterid_extent,
      'score_extent': score_extent
    };

    updatePlotsForObjective(objective);
  });
}

function updatePlotsForObjective(objective) {
  var data = objectivedata[objective];

  // set the main plot scale domains
  console.log(data['score_extent']);
  x.domain(data['iterid_extent']);
  y.domain(data['score_extent']);
  console.log(y.domain());

  // draw plots
  updateMain(data['runs']);
  updateTop(data['topdata']);
  updateLeft();
}

function setupPlots() {
  setupMain();
  setupTop();
  setupLeft();
}

function setupMain() {
  // draw the main plot
  // x-axis and labels
  mainsvg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis)
    .append("text")
      .attr("x", width)
      .attr("y", -16)
      .attr("dy", ".71em")
      .style("text-anchor", "end")
      .text("No. iterations");

  // y-axis and labels
  mainsvg.append("g")
      .attr("class", "y axis")
      .call(yAxis)
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", 6)
      .attr("dy", ".71em")
      .style("text-anchor", "end")
      .text("Score");
}

function setupLeft() {
  leftsvg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + height + ")")
    .call(lxAxis);
}

function setupTop() {
  topsvg.append("g")
      .attr("class", "y axis")
      .call(tyAxis);
}

function updateMain(runs) {

  // data join
  var run = mainsvg.selectAll(".run")
      .data(runs);

  // enter
  run.enter()
      .append("path")
      .attr("class", "run")
      .attr("class", "line")
      // on mouseover, highlight the path and display data
      .on('mouseover', function(d) { highlightPath(d3.select(this));
        d3.select('#opt').text(d.max);
        d3.select('#iter').text(d.n);
        d3.select('#levels').text(d.levels);
        d3.select('#params').text(d.params);
      });

  // update
  run.attr("d", function(d) { return line(d.values); })
      .attr("transform", null)
    .transition()
      .duration(500)
      .ease("linear")
      .attr("transform", "translate(" + x(-1) + ")")
      .each("end", tick);

  // exit
  run.exit().remove();

  // y axis
  mainsvg.select(".y")
        .transition()
        .call(yAxis);

  // x axis
  mainsvg.select(".x")
        .transition()
        .call(xAxis);
}

function updateLeft() {
  // generate left plot
  var lhistdata = d3.layout.histogram()
    .bins(y.ticks(35))
    (distributions[objective]);

  lx.domain(d3.extent(lhistdata, function(d) { return round(d.y); }));
  lxAxis.scale(lx);

  // data join
  var bars = leftsvg.selectAll(".bar")
      .data(lhistdata);

  // exit
  bars.exit().remove();

  // enter
  bars.enter()
      .append("rect")
      .attr("class", "bar");

  // update
  bars.attr("y", function(d) { return y(d.x) - 10; })
      .attr("x", function(d) { return lx(d.y); })
      .transition().delay(500)
      .attr("height", lhistdata[0].dx)
      .attr("width", function(d) { return lwidth - lx(d.y); });

  // axis
  leftsvg.select(".x")
        .transition()
        .call(lxAxis);
}

function updateTop(topdata) {
  // generate top plot
  var tophistdata = d3.layout.histogram()
    .bins(x.ticks(35))
    (topdata);

  ty.domain(d3.extent(tophistdata, function(d) { return round(d.y); }));
  tyAxis.scale(ty);

  // data join
  var bars = topsvg.selectAll(".bar")
      .data(tophistdata);

  // exit
  bars.exit().remove();

  // enter
  bars.enter()
      .append("rect")
      .attr("class", "bar")
      .attr("transform", function(d) { return "translate(" + x(d.x) + "," + ty(d.y) + ")"; });

  // update
  bars.attr("x", 1)
      .transition().delay(500)
      .attr("width", x(tophistdata[0].dx))
      .attr("height", function(d) { return theight - ty(d.y); });

  // axis
  topsvg.select(".y")
        .transition()
        .call(tyAxis);

}