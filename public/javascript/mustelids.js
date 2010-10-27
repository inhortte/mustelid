var link_assoc = new Array();
link_assoc["subfamily"] = "subfam";
link_assoc["genus"] = "gen";
link_assoc["species"] = "druh";

$(document).ready(function() {
    $("h1").css("color", "#b00");

    // Select boxes change -> ajax functions.
    $("#subfam_select").change(function() {
	var subfam = $("#subfam_select").val();
	$("#gen").load('/ajax/changeGenus/' + subfam);
    });

    // Admin form submits.
    $("#admin_button").click(function() {
	var prefix = link_assoc[$("#admin_form").attr("action").split("/").pop()];
	if(prefix == "gen") {
	    $("#" + prefix + "_subfam_id").val($("#subfam_select").val());
	}
	if(prefix == "druh") {
	    $("#" + prefix + "_gen_id").val($("#gen_select").val());
	}
	$("#admin_form").submit();
    });
});

