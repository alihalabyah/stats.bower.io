// Generated by CoffeeScript 1.7.1
(function() {
  var module;

  module = angular.module('B.Table.Pkgs', []);

  module.directive("bTablePkgs", function(bDataSvc) {
    return {
      templateUrl: 'b-table-pkgs/b-table-pkgs.html',
      restrict: 'E',
      link: function(scope) {
        bDataSvc.fetchAllP.then(function(data) {
          scope.pkgs = data.data.pkgs;
        });
        scope.hideAngular = true;
        scope.toggleHideAngular = function() {
          scope.hideAngular = !scope.hideAngular;
        };
      }
    };
  });

}).call(this);

//# sourceMappingURL=b-table-pkgs.map
