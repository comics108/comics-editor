$(function () {
	var element = $('[data-sortable]');
	element.sortable({
		axis: 'y',
		start: function (event, ui) {
			ui.item.data('startPos', ui.item.index());
		},
		update: function (event, ui) {
			move(ui.item.data('id'), ui.item.index() - ui.item.data('startPos'));
		}
	});

	function move(id, offset) {
		$.ajax({
			url: element.data('sortable'),
			type: 'post',
			data: { id: id, offset: offset },
			success: function (result) {
				window.location.reload();
			},
			error: function () {
				window.location.reload();
			}
		});
	}
});
