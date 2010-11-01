var link_assoc = new Array();
link_assoc["subfamily"] = "subfam";
link_assoc["genus"] = "gen";
link_assoc["species"] = "druh";

$(document).ready(function() {
    $("#headmustelid img").fadeIn("slow");
    $("h5").prepend("(").append(")");

    // Select boxes change -> ajax functions.
    $("#subfam_select").change(function() {
	var subfam = $("#subfam_select").val();
	$("#gen").load('/ajax/changeGenus/' + subfam);
    });

    // Admin form submits.
    // First, for new entries and entries being edited.
    $("#admin_button").click(function() {
	var path = $("#admin_form").attr("action").split("/");
	// In case we are editing instead of creating a new model,
	// the path will be /admin/prefix/id, and 'id' needs to be expunged.
	if(path.length == 4) {
	    path.pop();
	}
	var prefix = link_assoc[path.pop()];
	alert("prefix: " + prefix);
	if(prefix == "gen") {
	    $("#" + prefix + "_subfam_id").val($("#subfam_select").val());
	}
	if(prefix == "druh") {
	    $("#" + prefix + "_gen_id").val($("#gen_select").val());
	}
	$("#admin_form").submit();
    });
    // Secondly, for showing and hiding blocks of substrata.
    $("#latin_list > .line > .entry > a").click(function() {
	$(this).siblings("ul").each(function () {
	    if($(this).hasClass("none")) {
		$(this).removeClass("none");
	    } else {
		$(this).addClass("none");
	    }
	});
    });
    // Now, for the edit and delete links.
    $("form > a[id^='edit'],form > a[id^='delete']").click(function() {
	// alert($(this).parent().attr("action"));
	$(this).parent().submit();
    });
});

